import SwiftData
import XCTest
@testable import PrumoCore

/// Casos levantados na revisão independente da lógica financeira.
@MainActor
final class RevisaoTests: XCTestCase {
    private var container: ModelContainer!
    private func contexto() throws -> ModelContext {
        container = try EsquemaPrumo.container(emMemoria: true)
        return container.mainContext
    }

    // MARK: Servidor Pluggy configurável

    private func cliente(_ t: TransporteFalso) -> PluggyClient {
        PluggyClient(credenciais: PluggyCredenciais(clientID: "i", clientSecret: "s"), transporte: t, dormir: { _ in })
    }

    private func servidor(status: String = "UPDATED", execucao: String = "SUCCESS",
                          contas: String = #"{"page":1,"total":1,"totalPages":1,"results":[{"id":"acc-cc","type":"BANK","subtype":"CHECKING_ACCOUNT","name":"CC","balance":100,"currencyCode":"BRL","owner":"TITULAR TESTE","taxNumber":"12345678909"}]}"#,
                          transacoes: String = #"{"results":[],"next":null}"#,
                          investimentos: String = #"{"page":1,"total":0,"totalPages":1,"results":[]}"#,
                          emprestimos: String = #"{"page":1,"total":0,"totalPages":1,"results":[]}"#) -> TransporteFalso {
        TransporteFalso { r, _ in
            switch r.caminho {
            case "/auth": return (200, Data(#"{"apiKey":"K"}"#.utf8), [:])
            case "/items/ITEM":
                return (200, Data(#"{"id":"ITEM","connector":{"name":"Banco Teste"},"status":"\#(status)","executionStatus":"\#(execucao)"}"#.utf8), [:])
            case "/accounts": return (200, Data(contas.utf8), [:])
            case "/v2/transactions": return (200, Data(transacoes.utf8), [:])
            case "/bills": return (200, Data(#"{"page":1,"total":0,"totalPages":1,"results":[]}"#.utf8), [:])
            case "/investments": return (200, Data(investimentos.utf8), [:])
            case "/loans": return (200, Data(emprestimos.utf8), [:])
            default: return (404, Data("{}".utf8), [:])
            }
        }
    }

    private func motor(_ ctx: ModelContext, _ t: TransporteFalso, hoje: Date = data(2026, 10, 13)) -> MotorDeSincronizacao {
        ctx.insert(Conexao(itemID: "ITEM", nome: ""))
        try? ctx.save()
        return MotorDeSincronizacao(contexto: ctx, cliente: cliente(t), agora: { hoje })
    }

    // MARK: 1. Pagamento de fatura

    func testPagamentoDaFaturaSoEhInternoQuandoOCartaoEstaNoApp() throws {
        let ctx = try contexto()
        let banco = Conta(externalID: "nuconta", nome: "NuConta", tipo: .corrente)
        let cartao = Conta(externalID: "nucartao", nome: "Nubank", tipo: .cartao)
        [banco, cartao].forEach(ctx.insert)
        let debito = Lancamento(externalID: "d1", contaID: "nuconta", data: data(2026, 10, 10), descricao: "Pagamento da fatura",
                                valorCentavos: -300_000, origem: .openFinance)
        debito.categoriaChave = "fatura"
        let recebido = Lancamento(externalID: "p1", contaID: "nucartao", data: data(2026, 10, 10), descricao: "Pagamento recebido",
                                  valorCentavos: 300_000, origem: .openFinance)
        recebido.categoriaChave = "fatura"; recebido.interno = true
        // Outro débito com mesmo texto mas sem par (cartão de outro banco que o app não acompanha).
        let semPar = Lancamento(externalID: "d2", contaID: "nuconta", data: data(2026, 10, 12), descricao: "Pagamento da fatura",
                                valorCentavos: -150_000, origem: .openFinance)
        semPar.categoriaChave = "fatura"
        [debito, recebido, semPar].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.parearFaturas(ctx), 1)
        XCTAssertTrue(debito.interno)
        XCTAssertFalse(semPar.interno, "fatura de cartão que o app não vê é gasto real")
    }

    func testSemCartaoNoAppNadaEhMarcadoInterno() throws {
        let ctx = try contexto()
        ctx.insert(Conta(externalID: "cc", nome: "CC", tipo: .corrente))
        let d = Lancamento(externalID: "d", contaID: "cc", data: data(2026, 10, 10), descricao: "Pagamento da fatura", valorCentavos: -100_000, origem: .openFinance)
        ctx.insert(d)
        XCTAssertEqual(try Conciliador.parearFaturas(ctx), 0)
        XCTAssertFalse(d.interno)
    }

    // MARK: 3. Empréstimo conforme a spec

    func testEmprestimoLeCamposDaSpec() async throws {
        let ctx = try contexto()
        let loan = #"{"page":1,"total":1,"totalPages":1,"results":[{"id":"L1","productName":"Crédito pessoal","contractAmount":30000.00,"dueDate":"2029-09-10T00:00:00.000Z","firstInstallmentDueDate":"2026-06-10T00:00:00.000Z","CET":0.31,"installments":{"totalNumberOfInstallments":36,"paidInstallments":4,"dueInstallments":32,"contractRemainingNumber":32},"payments":{"contractOutstandingBalance":22350.75}}]}"#
        // Dia 5/10: a 5ª parcela (1ª em jun + 4 pagas) vence em 10/10, ainda no futuro.
        let m = motor(ctx, servidor(emprestimos: loan), hoje: data(2026, 10, 5))
        let r = await m.sincronizarTudo()
        XCTAssertTrue(r.erros.isEmpty, "\(r.erros)")
        let e = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Emprestimo>()).first)
        XCTAssertEqual(e.saldoDevedorCentavos, 2_235_075)
        XCTAssertEqual(e.parcelasRestantes, 32)
        XCTAssertNotNil(e.proximoVencimento, "a parcela precisa aparecer nos vencimentos")
        XCTAssertEqual(Datas.calendario.component(.month, from: e.proximoVencimento!), 10, "1ª em jun + 4 pagas = 5ª em out")
        XCTAssertEqual(Datas.calendario.component(.day, from: e.proximoVencimento!), 10)
        let p = Patrimonio.calcular(contas: try ctx.fetch(FetchDescriptor<Conta>()), investimentos: [], emprestimos: [e])
        XCTAssertGreaterThanOrEqual(p.emprestimosCentavos, 2_235_075)
    }

    func testEmprestimoComParcelaJaVencidaMostraAProximaFutura() async throws {
        let ctx = try contexto()
        let loan = #"{"page":1,"total":1,"totalPages":1,"results":[{"id":"L2","productName":"Crédito pessoal","contractAmount":30000.00,"firstInstallmentDueDate":"2026-06-10T00:00:00.000Z","installments":{"totalNumberOfInstallments":36,"paidInstallments":4,"contractRemainingNumber":32},"payments":{"contractOutstandingBalance":22350.75}}]}"#
        let m = motor(ctx, servidor(emprestimos: loan), hoje: data(2026, 10, 13))
        _ = await m.sincronizarTudo()
        let e = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Emprestimo>()).first)
        XCTAssertEqual(Datas.calendario.component(.month, from: e.proximoVencimento!), 11)
    }

    // MARK: 4. Moeda estrangeira

    func testCompraEmDolarUsaOValorEmReais() throws {
        let json = #"{"id":"t","description":"OPENAI *CHATGPT","amount":20.00,"amountInAccountCurrency":110.50,"currencyCode":"USD","date":"2026-10-05T00:00:00.000Z","type":"DEBIT","status":"POSTED","accountId":"c"}"#
        let t = try PluggyJSON.decoder().decode(PluggyTransacao.self, from: Data(json.utf8))
        XCTAssertEqual(Mapeador.valorAssinado(t, tipoConta: .cartao), -11_050)
    }

    // MARK: 5/6. Sincronização com resposta parcial ou data futura

    func testParcelaFuturaNaoAdiantaAJanelaDaBusca() async throws {
        let ctx = try contexto()
        let futura = Lancamento(externalID: "f", contaID: "acc-cc", data: data(2027, 2, 10), descricao: "PARCELA", valorCentavos: -5000, origem: .openFinance)
        futura.status = .pendente
        let passada = Lancamento(externalID: "p", contaID: "acc-cc", data: data(2026, 9, 20), descricao: "COMPRA", valorCentavos: -1000, origem: .openFinance)
        [futura, passada].forEach(ctx.insert)
        let t = servidor()
        let m = motor(ctx, t)
        _ = await m.sincronizarTudo()
        let pedido = try XCTUnwrap(t.registro.last { $0.caminho == "/v2/transactions" })
        let desde = try XCTUnwrap(pedido.consulta["dateFrom"])
        XCTAssertLessThan(desde, "2026-10-01", "âncora é a compra de setembro, não a parcela de fevereiro")
    }

    func testAtualizacaoParcialNaoApagaNemDesativaNada() async throws {
        let ctx = try contexto()
        let pendente = Lancamento(externalID: "pend", contaID: "acc-cc", data: data(2026, 10, 11), descricao: "COMPRA", valorCentavos: -2000, origem: .openFinance)
        pendente.status = .pendente
        pendente.categoriaManual = true; pendente.notas = "importante"
        let inv = Investimento(externalID: "inv1", nome: "CDB", classe: .rendaFixa, saldoCentavos: 5_000_000)
        inv.conexaoItemID = "ITEM"
        [pendente].forEach(ctx.insert); ctx.insert(inv)
        // Item ainda atualizando e respostas vazias.
        let m = motor(ctx, servidor(status: "UPDATING", execucao: "PARTIAL_SUCCESS"))
        let r = await m.sincronizarTudo()
        XCTAssertTrue(r.parcial)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Lancamento>()), 1, "nada some por causa de resposta vazia")
        XCTAssertTrue(inv.ativo)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<FotoPatrimonio>()), 0, "foto parcial mostraria patrimônio menor")
    }

    func testPendenteEditadoQueSomeViraIgnoradoENaoEhApagado() async throws {
        let ctx = try contexto()
        let editado = Lancamento(externalID: "pend", contaID: "acc-cc", data: data(2026, 10, 11), descricao: "COMPRA", valorCentavos: -2000, origem: .openFinance)
        editado.status = .pendente; editado.notas = "minha nota"
        ctx.insert(editado)
        let tx = #"{"results":[{"id":"outra","description":"X","amount":-10,"date":"2026-10-12T00:00:00.000Z","type":"DEBIT","status":"POSTED","accountId":"acc-cc"}],"next":null}"#
        let m = motor(ctx, servidor(transacoes: tx))
        _ = await m.sincronizarTudo()
        XCTAssertTrue(editado.ignorado)
        XCTAssertEqual(editado.notas, "minha nota")
    }

    // MARK: 7. Categoria manual neutra mantém "interno" na próxima sincronização

    func testCategoriaManualNeutraSobreviveAoSync() async throws {
        let ctx = try contexto()
        let tx = #"{"results":[{"id":"pix1","description":"Pix enviado Joao","amount":-2000,"date":"2026-10-12T00:00:00.000Z","type":"DEBIT","status":"POSTED","accountId":"acc-cc"}],"next":null}"#
        let m = motor(ctx, servidor(transacoes: tx))
        _ = await m.sincronizarTudo()
        let l = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Lancamento>()).first { $0.externalID == "pix1" })
        XCTAssertFalse(l.interno)
        l.categoriaChave = "transferencia"; l.categoriaManual = true; l.interno = true   // o que a tela faz
        try ctx.save()
        _ = await m.sincronizarTudo()
        XCTAssertTrue(l.interno, "continua fora do gasto")
        // E o inverso: escolher uma categoria de despesa para o que era interno tira do "interno".
        l.categoriaChave = "presentes"
        _ = await m.sincronizarTudo()
        XCTAssertFalse(l.interno)
    }

    // MARK: 8/9/10. Conciliação

    func testNaoCasaToqueComPixDeMesmoValor() throws {
        let ctx = try contexto()
        let toque = Lancamento(externalID: "w", contaID: "", data: data(2026, 10, 13), descricao: "POSTO IPIRANGA", valorCentavos: -5000, origem: .carteira)
        let pix = Lancamento(externalID: "b", contaID: "cc", data: data(2026, 10, 9), descricao: "Pix enviado Maria", valorCentavos: -5000, origem: .openFinance)
        [toque, pix].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 0, "banco nunca lança 4 dias antes do toque, e o texto não bate")
    }

    func testNaoUsaLancamentoInternoNaConciliacao() throws {
        let ctx = try contexto()
        let toque = Lancamento(externalID: "w", contaID: "", data: data(2026, 10, 13), descricao: "UBER", valorCentavos: -2300, origem: .carteira)
        let interno = Lancamento(externalID: "b", contaID: "cc", data: data(2026, 10, 13), descricao: "UBER TRANSFERENCIA", valorCentavos: -2300, origem: .openFinance)
        interno.interno = true
        [toque, interno].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 0)
    }

    func testImportadoTambemEhOficial() throws {
        let ctx = try contexto()
        let toque = Lancamento(externalID: "w", contaID: "", data: data(2026, 10, 12), descricao: "PADARIA PAO QUENTE", valorCentavos: -4590, origem: .carteira)
        let csv = Lancamento(externalID: "imp-1", contaID: "cartao", data: data(2026, 10, 13), descricao: "PADARIA PAO QUENTE", valorCentavos: -4590, origem: .importado)
        [toque, csv].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 1)
    }

    func testToqueParceladoCasaComAParcela() throws {
        let ctx = try contexto()
        let toque = Lancamento(externalID: "w", contaID: "", data: data(2026, 10, 12), descricao: "MAGAZINE LUIZA", valorCentavos: -100_000, origem: .carteira)
        let parcela = Lancamento(externalID: "b", contaID: "c", data: data(2026, 10, 12), descricao: "MAGAZINE LUIZA PARC 1/10", valorCentavos: -10_000, origem: .openFinance)
        parcela.parcelaAtual = 1; parcela.totalParcelas = 10
        [toque, parcela].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 1)
        XCTAssertFalse(toque.contaParaRelatorios)
    }

    // MARK: 11. Devoluções

    func testEstornoAbateACategoriaDaCompraEmContaCorrente() throws {
        let ctx = try contexto()
        let cc = Conta(externalID: "cc", nome: "CC", tipo: .corrente)
        ctx.insert(cc)
        let compra = Lancamento(externalID: "c", contaID: "cc", data: data(2026, 10, 2), descricao: "LOJA", valorCentavos: -30_000, origem: .openFinance)
        compra.categoriaChave = "compras"
        let estorno = Lancamento(externalID: "e", contaID: "cc", data: data(2026, 10, 5), descricao: "ESTORNO COMPRA", valorCentavos: 30_000, origem: .openFinance)
        estorno.categoriaChave = "reembolsos"
        [compra, estorno].forEach(ctx.insert)
        let r = Analise.resumoDoMes(data(2026, 10, 13), lancamentos: [compra, estorno], contas: [cc], hoje: data(2026, 10, 13))
        XCTAssertEqual(r.receitasCentavos, 0, "estorno não é renda")
        XCTAssertEqual(r.despesasCentavos, 0)
        XCTAssertNil(r.porCategoria.first { $0.chave == "compras" }, "a categoria também zerou")
    }

    // MARK: 13/12. Gasto do mês, previsão

    func testGastoDoMesNaoContaParcelaFutura() throws {
        let ctx = try contexto()
        let cartao = Conta(externalID: "c", nome: "Cartão", tipo: .cartao)
        ctx.insert(cartao)
        let hoje = data(2026, 10, 13)
        let passada = Lancamento(externalID: "1", contaID: "c", data: data(2026, 10, 5), descricao: "LOJA", valorCentavos: -20_000, origem: .openFinance)
        let futura = Lancamento(externalID: "2", contaID: "c", data: data(2026, 10, 25), descricao: "LOJA PARC 2/3", valorCentavos: -50_000, origem: .openFinance)
        futura.status = .pendente
        [passada, futura].forEach(ctx.insert)
        let mes = Analise.resumoDoMes(hoje, lancamentos: [passada, futura], contas: [cartao], hoje: hoje)
        XCTAssertEqual(mes.despesasCentavos, 20_000)
        let p = Analise.previsaoDoMes(lancamentos: [passada, futura], contas: [cartao], hoje: hoje)
        XCTAssertGreaterThanOrEqual(p.projetadoCentavos, 70_000, "o compromisso futuro entra na previsão")
        XCTAssertGreaterThanOrEqual(p.projetadoCentavos, mes.despesasCentavos)
    }

    func testPrevisaoNaoSuperestimaComAluguelNoComecoDoMes() throws {
        let ctx = try contexto()
        try DadosDemo.popular(ctx, hoje: data(2026, 10, 13))
        let lancs = try ctx.fetch(FetchDescriptor<Lancamento>())
        let contas = try ctx.fetch(FetchDescriptor<Conta>())
        let p = Analise.previsaoDoMes(lancamentos: lancs, contas: contas, hoje: data(2026, 10, 13))
        XCTAssertGreaterThan(p.mediaMensalCentavos, 0)
        XCTAssertLessThan(p.projetadoCentavos, Int(Double(p.mediaMensalCentavos) * 1.4),
                          "projetado \(p.projetadoCentavos) vs média \(p.mediaMensalCentavos)")
    }

    // MARK: Demo coerente

    func testDemoNaoContaPagamentoDeFaturaComoGasto() throws {
        let ctx = try contexto()
        let hoje = data(2026, 10, 13)
        try DadosDemo.popular(ctx, hoje: hoje)
        let lancs = try ctx.fetch(FetchDescriptor<Lancamento>())
        let contas = try ctx.fetch(FetchDescriptor<Conta>())
        let faturasNaConta = lancs.filter { $0.categoriaChave == "fatura" && $0.valorCentavos < 0 }
        XCTAssertFalse(faturasNaConta.isEmpty)
        XCTAssertTrue(faturasNaConta.allSatisfy(\.interno), "o cartão está no app: pagar a fatura não é gasto novo")
        // Nenhum mês do demo pode gastar mais do que o dobro do que entra: sinal de fatura contada em dobro.
        for m in 1...3 {
            let ref = Datas.somar(meses: -m, a: hoje)
            let r = Analise.resumoDoMes(ref, lancamentos: lancs, contas: contas, hoje: hoje)
            XCTAssertLessThan(r.despesasCentavos, 1_300_000, "mês -\(m): gasto \(r.despesasCentavos)")
        }
    }

    // MARK: 14. Transferência própria

    func testDocumentoMascaradoEPorNomeSaoReconhecidos() throws {
        let json = #"{"id":"t","description":"Pix enviado","amount":-2000,"date":"2026-10-05T00:00:00.000Z","type":"DEBIT","status":"POSTED","accountId":"c","paymentData":{"payer":{"name":"TITULAR TESTE","documentNumber":{"type":"CPF","value":"***456789**"}},"receiver":{"name":"Titular Teste","documentNumber":{"type":"CPF","value":"***456789**"}}}}"#
        let t = try PluggyJSON.decoder().decode(PluggyTransacao.self, from: Data(json.utf8))
        XCTAssertTrue(Mapeador.lancamento(t, contaID: "c", tipoConta: .corrente, documentoTitular: "12345678909").transferenciaPropria)
        XCTAssertTrue(Mapeador.lancamento(t, contaID: "c", tipoConta: .corrente, documentoTitular: nil, nomeTitular: "TITULAR TESTE").transferenciaPropria)
        XCTAssertFalse(Mapeador.lancamento(t, contaID: "c", tipoConta: .corrente, documentoTitular: nil, nomeTitular: "OUTRA PESSOA").transferenciaPropria)
    }

    func testParDeTransferenciaEntreContasProprias() throws {
        let ctx = try contexto()
        ctx.insert(Conta(externalID: "a", nome: "A", tipo: .corrente)); ctx.insert(Conta(externalID: "b", nome: "B", tipo: .poupanca))
        let s = Lancamento(externalID: "s", contaID: "a", data: data(2026, 10, 10), descricao: "Pix enviado", valorCentavos: -200_000, origem: .openFinance)
        let e = Lancamento(externalID: "e", contaID: "b", data: data(2026, 10, 10), descricao: "Pix recebido", valorCentavos: 200_000, origem: .openFinance)
        let aluguel = Lancamento(externalID: "al", contaID: "a", data: data(2026, 10, 8), descricao: "Pix enviado Imobiliaria", valorCentavos: -240_000, origem: .openFinance)
        [s, e, aluguel].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.parearTransferenciasProprias(ctx), 1)
        XCTAssertTrue(s.interno && e.interno)
        XCTAssertFalse(aluguel.interno)
    }

    // MARK: 16. Lista tolerante e crashes

    func testRegistroRuimNaoDerrubaAPagina() throws {
        let json = #"{"results":[{"id":"ok","description":"A","amount":-10,"date":"2026-10-05T00:00:00.000Z","type":"DEBIT"},{"id":"ruim","description":"B","amount":null,"date":"2026-10-05T00:00:00.000Z"},{"id":"ok2","description":"C","amount":5,"date":"2026-10-06T00:00:00.000Z","type":"CREDIT"}],"next":null}"#
        let p = try PluggyJSON.decoder().decode(PluggyPaginaCursor<PluggyTransacao>.self, from: Data(json.utf8))
        XCTAssertEqual(p.results.map(\.id), ["ok", "ok2"])
    }

    func testValoresAbsurdosNaoEstouram() {
        XCTAssertNil(Dinheiro.ler("99999999999999999999,99"))
        XCTAssertEqual(Dinheiro.ler("1234567890123"), 123_456_789_012_300)
    }

    // MARK: 17/18. Importador

    func testDatasDeDoisDigitosEFormatoAmericano() throws {
        let br = try Importador.ler(Data("Data;Descrição;Valor\n11/06/25;CAFE;-10,00\n12/06/25;PADARIA;-20,00\n".utf8))
        XCTAssertEqual(Datas.calendario.component(.year, from: br[0].data), 2025)
        let us = try Importador.ler(Data("Date,Description,Amount\n06/25/2026,Coffee,-3.50\n06/11/2026,Lunch,-12.00\n".utf8))
        XCTAssertEqual(Datas.calendario.component(.month, from: us[0].data), 6)
        XCTAssertEqual(Datas.calendario.component(.day, from: us[0].data), 25)
        XCTAssertEqual(Datas.calendario.component(.month, from: us[1].data), 6, "06/11 em arquivo americano é 11 de junho")
    }

    func testValoresComSufixoDebitoCreditoEOFXFlexivel() throws {
        XCTAssertEqual(Importador.valorComSinal("45,90 D"), -4590)
        XCTAssertEqual(Importador.valorComSinal("1.234,56 C"), 123_456)
        XCTAssertEqual(Importador.valorComSinal("-1.234,56"), -123_456)
        XCTAssertEqual(Importador.valorComSinal("-1,234.56"), -123_456)
        XCTAssertNil(Importador.valorComSinal("abc"))
        let ofx = """
        <ofx><stmttrn><trntype>DEBIT<dtposted>20261005<trnamt>-1.234,56<fitid>A<memo>COMPRA GRANDE</stmttrn>
        <stmttrn><trntype>CREDIT<dtposted>20261005<trnamt>1500.00<fitid>B<memo>SALDO ANTERIOR</stmttrn></ofx>
        """
        let linhas = try Importador.ler(Data(ofx.utf8))
        XCTAssertEqual(linhas.count, 1, "linha de saldo não é movimentação")
        XCTAssertEqual(linhas[0].valorCentavos, -123_456)
        let cartao = try Importador.ler(Data("<STMTTRN><DTPOSTED>20261005<TRNAMT>54.90<FITID>C<MEMO>NETFLIX</STMTTRN>".utf8), cartaoPositivoEhGasto: true)
        XCTAssertEqual(cartao[0].valorCentavos, -5490)
    }

    func testImportacaoNaoDuplicaComOQueOBancoJaTrouxe() throws {
        let ctx = try contexto()
        let conta = Conta(externalID: "cc", nome: "CC", tipo: .corrente)
        ctx.insert(conta)
        ctx.insert(Lancamento(externalID: "of1", contaID: "cc", data: data(2026, 10, 5), descricao: "CAFE", valorCentavos: -1000, origem: .openFinance))
        let r = try Importador.gravar([
            LinhaImportada(data: data(2026, 10, 5), descricao: "CAFE", valorCentavos: -1000, identificador: nil),
            LinhaImportada(data: data(2026, 10, 6), descricao: "PADARIA", valorCentavos: -2000, identificador: nil),
        ], em: conta, ctx)
        XCTAssertEqual(r.novas, 1)
        XCTAssertEqual(r.repetidas, 1)
    }

    // MARK: 22/23. Recorrentes e Apple Pay

    func testParcelaNaoVirarAssinatura() throws {
        let ctx = try contexto()
        let cartao = Conta(externalID: "c", nome: "Cartão", tipo: .cartao)
        ctx.insert(cartao)
        var lancs: [Lancamento] = []
        for m in 0..<4 {
            let d = Datas.somar(meses: -m, a: data(2026, 10, 6))
            let l = Lancamento(externalID: "p\(m)", contaID: "c", data: d, descricao: "APPLE STORE NOTEBOOK PARC \(4 - m)/10", valorCentavos: -48_990, origem: .openFinance)
            l.parcelaAtual = 4 - m; l.totalParcelas = 10
            ctx.insert(l); lancs.append(l)
        }
        XCTAssertTrue(Analise.recorrentes(lancamentos: lancs, contas: [cartao], hoje: data(2026, 10, 13)).isEmpty)
    }

    func testApplePayEmDolarEEstornoSaoTratadosComCuidado() throws {
        let ctx = try contexto()
        _ = try Carteira.registrar(ctx, valorTexto: "US$ 20,00", estabelecimento: "OpenAI", cartao: "")
        let dolar = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Lancamento>()).first)
        XCTAssertNotNil(dolar.notas, "avisa que o valor está em moeda estrangeira")
        _ = try Carteira.registrar(ctx, valorTexto: "-R$ 45,90", estabelecimento: "Loja X", cartao: "")
        let estorno = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Lancamento>()).first { $0.descricao == "Loja X" })
        XCTAssertEqual(estorno.valorCentavos, 4590)
        XCTAssertEqual(estorno.categoriaChave, "reembolsos")
    }

    // MARK: 25. Retry-After inválido não derruba o app

    func testRetryAfterInvalidoNaoQuebra() async throws {
        let t = TransporteFalso { r, ordem in
            switch r.caminho {
            case "/auth": return (200, Data(#"{"apiKey":"K"}"#.utf8), [:])
            case "/items/x": return ordem < 2 ? (429, Data("{}".utf8), ["Retry-After": "nan"]) : (200, try fixture("item"), [:])
            default: return (404, Data("{}".utf8), [:])
            }
        }
        _ = try await cliente(t).item("x")
        XCTAssertEqual(t.contar(caminho: "/items/x"), 2)
    }
}
