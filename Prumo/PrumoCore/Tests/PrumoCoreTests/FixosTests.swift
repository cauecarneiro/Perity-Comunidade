import SwiftData
import XCTest
@testable import PrumoCore

@MainActor
final class FixosTests: XCTestCase {
    private let hoje = data(2026, 10, 13)
    private var container: ModelContainer!

    private func gasto(_ id: String, _ dia: Date, _ desc: String, _ centavos: Int, categoria: String = "outros") -> Lancamento {
        let l = Lancamento(externalID: id, contaID: "c", data: dia, descricao: desc, valorCentavos: -centavos, origem: .openFinance)
        l.categoriaChave = categoria
        return l
    }

    func testChaveDoMes() {
        XCTAssertEqual(Fixos.chaveMes(data(2026, 10, 13)), "2026-10")
        XCTAssertEqual(Fixos.chaveMes(data(2027, 1, 2)), "2027-01")
    }

    func testDetectaPagamentoEUsaOValorDoExtrato() {
        let academia = Fixo(nome: "Academia", valorCentavos: 29_900, padrao: "smart fit")
        let seguro = Fixo(nome: "Seguro", valorCentavos: 38_600)
        let lancs = [gasto("1", data(2026, 10, 2), "SMART FIT ACADEMIA", 31_990)]
        let s = Fixos.situacao(fixos: [academia, seguro], marcas: [], lancamentos: lancs, mes: hoje)
        XCTAssertEqual(s.count, 2)
        XCTAssertTrue(s[0].pago)
        XCTAssertTrue(s[0].detectado)
        XCTAssertEqual(s[0].valorCentavos, 31_990, "vale o que saiu de verdade, não o combinado")
        XCTAssertEqual(s[0].faltaCentavos, 0)
        XCTAssertFalse(s[1].pago)
        XCTAssertEqual(s[1].faltaCentavos, 38_600)
        let r = Fixos.resumo(s)
        XCTAssertEqual(r.quantidade, 2)
        XCTAssertEqual(r.pagos, 1)
        XCTAssertEqual(r.totalCentavos, 31_990 + 38_600)
        XCTAssertEqual(r.faltaCentavos, 38_600)
        XCTAssertEqual(r.pagoCentavos, 31_990)
    }

    func testSemPadraoUsaONomeEAceitaAlternativas() {
        let spotify = Fixo(nome: "Spotify", valorCentavos: 1_290)
        let claude = Fixo(nome: "Claude", valorCentavos: 50_000, padrao: "claude, anthropic")
        let lancs = [
            gasto("1", data(2026, 10, 3), "SPOTIFY BRASIL", 1_290),
            gasto("2", data(2026, 10, 5), "ANTHROPIC PBC", 55_000),
        ]
        let s = Fixos.situacao(fixos: [spotify, claude], marcas: [], lancamentos: lancs, mes: hoje)
        XCTAssertTrue(s[0].pago)
        XCTAssertTrue(s[1].pago)
        XCTAssertEqual(s[1].valorCentavos, 55_000)
    }

    func testDoisFixosNaoDisputamOMesmoLancamento() {
        let fixo = Fixo(nome: "Vivo Fixo", valorCentavos: 8_999, padrao: "vivo")
        fixo.ordem = 0
        let movel = Fixo(nome: "Vivo Móvel", valorCentavos: 19_995, padrao: "vivo")
        movel.ordem = 1
        let lancs = [
            gasto("a", data(2026, 10, 4), "VIVO SP", 19_995),
            gasto("b", data(2026, 10, 6), "VIVO SP", 8_999),
        ]
        let s = Fixos.situacao(fixos: [fixo, movel], marcas: [], lancamentos: lancs, mes: hoje)
        XCTAssertEqual(s[0].lancamentoIDs, ["b"], "cada um fica com a cobrança de valor mais próximo")
        XCTAssertEqual(s[1].lancamentoIDs, ["a"])

        // Só uma cobrança no mês: só um dos dois fica pago.
        let um = Fixos.situacao(fixos: [fixo, movel], marcas: [], lancamentos: [lancs[1]], mes: hoje)
        XCTAssertEqual(um.filter(\.pago).count, 1)
    }

    func testMarcaManualPagaEDesfazDeteccao() {
        let faxina = Fixo(nome: "Faxina", valorCentavos: 50_000, forma: .pix)
        let spotify = Fixo(nome: "Spotify", valorCentavos: 1_290)
        let lancs = [gasto("1", data(2026, 10, 3), "SPOTIFY", 1_290)]
        let marcas = [
            MarcaFixo(fixoUID: faxina.uid, mes: "2026-10", pago: true),
            MarcaFixo(fixoUID: spotify.uid, mes: "2026-10", pago: false),
            MarcaFixo(fixoUID: faxina.uid, mes: "2026-09", pago: false),
        ]
        let s = Fixos.situacao(fixos: [faxina, spotify], marcas: marcas, lancamentos: lancs, mes: hoje)
        XCTAssertTrue(s[0].pago)
        XCTAssertTrue(s[0].manual)
        XCTAssertFalse(s[0].detectado)
        XCTAssertFalse(s[1].pago, "desmarcado à mão vence a detecção")
        XCTAssertTrue(s[1].detectado)
    }

    func testAcumulaPorCategoriaEPorPadrao() {
        let mercado = Fixo(nome: "Mercado", valorCentavos: 180_000, categoriaChave: "mercado", acumula: true)
        let gasolina = Fixo(nome: "Gasolina", valorCentavos: 80_000, categoriaChave: "transporte", padrao: "posto, shell", acumula: true)
        let lancs = [
            gasto("1", data(2026, 10, 2), "CARREFOUR", 30_000, categoria: "mercado"),
            gasto("2", data(2026, 10, 9), "ASSAI", 25_000, categoria: "mercado"),
            gasto("3", data(2026, 10, 5), "POSTO IPIRANGA CENTRO", 20_000, categoria: "transporte"),
            gasto("4", data(2026, 10, 7), "UBER TRIP", 3_000, categoria: "transporte"),
            gasto("5", data(2026, 9, 28), "CARREFOUR", 99_000, categoria: "mercado"),
        ]
        let s = Fixos.situacao(fixos: [mercado, gasolina], marcas: [], lancamentos: lancs, mes: hoje)
        XCTAssertEqual(s[0].gastoCentavos, 55_000, "só o mês pedido")
        XCTAssertFalse(s[0].pago, "soma do mês não se marca sozinha")
        XCTAssertEqual(s[0].faltaCentavos, 125_000)
        XCTAssertEqual(s[1].gastoCentavos, 20_000, "Uber não é gasolina")

        // Fechado à mão: passa a valer o que saiu de verdade.
        let fechado = Fixos.situacao(fixos: [mercado], marcas: [MarcaFixo(fixoUID: mercado.uid, mes: "2026-10", pago: true)],
                                     lancamentos: lancs, mes: hoje)
        XCTAssertTrue(fechado[0].pago)
        XCTAssertEqual(fechado[0].valorCentavos, 55_000)
        XCTAssertEqual(fechado[0].faltaCentavos, 0)
    }

    func testReferenciaVemDoMesAnteriorQuandoAindaNaoPagou() {
        let luz = Fixo(nome: "Luz", valorCentavos: 20_000, padrao: "enel")
        let lancs = [
            gasto("1", data(2026, 8, 15), "ENEL DISTRIBUICAO", 21_000),
            gasto("2", data(2026, 9, 15), "ENEL DISTRIBUICAO", 24_350),
        ]
        let s = Fixos.situacao(fixos: [luz], marcas: [], lancamentos: lancs, mes: hoje)
        XCTAssertFalse(s[0].pago)
        XCTAssertEqual(s[0].valorCentavos, 24_350, "sem cobrança no mês, usa o último valor real")
    }

    func testParcelaEIgnoradosEInativos() {
        let dentista = Fixo(nome: "Dentista", valorCentavos: 120_000, padrao: "odonto")
        let antigo = Fixo(nome: "Antigo", valorCentavos: 100)
        antigo.ativo = false
        let parcela = gasto("1", data(2026, 10, 6), "ODONTO CLINIC PARC 2/3", 120_000)
        parcela.parcelaAtual = 2
        parcela.totalParcelas = 3
        let s = Fixos.situacao(fixos: [dentista, antigo], marcas: [], lancamentos: [parcela], mes: hoje)
        XCTAssertEqual(s.count, 1, "inativo não aparece")
        XCTAssertEqual(s[0].parcelaAtual, 2)
        XCTAssertEqual(s[0].totalParcelas, 3)

        parcela.ignorado = true
        XCTAssertFalse(Fixos.situacao(fixos: [dentista], marcas: [], lancamentos: [parcela], mes: hoje)[0].pago)
    }

    func testLerListaColada() {
        let texto = """
        Gasolina; 800,00; Cartão Crédito; Carro; soma; extrato=posto, shell
        Consórcio\tR$ 1.443,16\tBoleto\tCarro
        Faxina; 500; PIX; Casa
        Dentista 3x; 1.200,00; cartão; saúde

        linha sem valor
        """
        let itens = Fixos.ler(texto)
        XCTAssertEqual(itens.count, 4)
        XCTAssertEqual(itens[0], RascunhoFixo(nome: "Gasolina", valorCentavos: 80_000, forma: .cartao,
                                              categoriaChave: "carro", padrao: "posto, shell", acumula: true))
        XCTAssertEqual(itens[1].nome, "Consórcio")
        XCTAssertEqual(itens[1].valorCentavos, 144_316)
        XCTAssertEqual(itens[1].forma, .boleto)
        XCTAssertEqual(itens[2].forma, .pix)
        XCTAssertEqual(itens[2].categoriaChave, "moradia")
        XCTAssertEqual(itens[3].nome, "Dentista 3x", "número no nome não vira valor")
        XCTAssertEqual(itens[3].valorCentavos, 120_000)
        XCTAssertEqual(itens[3].categoriaChave, "saude")
    }

    func testSugestoesIgnoramOQueJaEstaNaLista() throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        try DadosDemo.popular(ctx, hoje: hoje)
        let contas = try ctx.fetch(FetchDescriptor<Conta>())
        let lancs = try ctx.fetch(FetchDescriptor<Lancamento>())
        let fixos = try ctx.fetch(FetchDescriptor<Fixo>())
        let marcas = try ctx.fetch(FetchDescriptor<MarcaFixo>())
        XCTAssertEqual(fixos.count, 15)

        let rec = Analise.recorrentes(lancamentos: lancs, contas: contas, hoje: hoje)
        let todas = Fixos.sugestoes(recorrentes: rec, fixos: [])
        let restantes = Fixos.sugestoes(recorrentes: rec, fixos: fixos)
        XCTAssertGreaterThan(todas.count, restantes.count)
        XCTAssertFalse(restantes.contains { Texto.normalizar($0.nome).contains("spotify") })
        XCTAssertFalse(todas.contains(where: \.ehReceita))

        // No exemplo, o que já foi cobrado no mês aparece pago sem ninguém marcar.
        let s = Fixos.situacao(fixos: fixos, marcas: marcas, lancamentos: lancs, mes: hoje)
        XCTAssertEqual(s.count, 15)
        XCTAssertTrue(s.first { $0.nome == "Aluguel" }!.pago)
        XCTAssertTrue(s.first { $0.nome == "Aluguel" }!.detectado)
        XCTAssertTrue(s.first { $0.nome == "Faxina" }!.manual)
        XCTAssertFalse(s.first { $0.nome == "Plano de saúde" }!.pago)
        XCTAssertGreaterThan(s.first { $0.nome == "Mercado" }!.gastoCentavos, 0)
        let novo = Fixos.novo(de: todas[0], ehCartao: true)
        XCTAssertFalse(novo.padrao.isEmpty)

        try DadosDemo.limpar(ctx)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Fixo>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<MarcaFixo>()).count, 0)
    }

    // MARK: Varredura, data de débito e histórico

    private func gastoEm(_ conta: String, _ id: String, _ dia: Date, _ desc: String, _ centavos: Int, categoria: String = "outros") -> Lancamento {
        let l = gasto(id, dia, desc, centavos, categoria: categoria)
        l.contaID = conta
        return l
    }

    private func cartao(fechamento: Date? = nil, vencimento: Date? = nil) -> Conta {
        let c = Conta(externalID: "cart", nome: "Cartão Azul", tipo: .cartao, instituicao: "Banco Azul")
        c.fechamentoFatura = fechamento
        c.vencimentoFatura = vencimento
        return c
    }

    private func fatura(_ id: String, fechamento: Date, vencimento: Date) -> Fatura {
        let f = Fatura(externalID: id, contaID: "cart", vencimento: vencimento, totalCentavos: 100_000)
        f.fechamento = fechamento
        return f
    }

    func testVarreduraCriaFixoSozinhoENaoRecriaODesativado() {
        let cartao = cartao()
        let cc = Conta(externalID: "cc", nome: "Conta", tipo: .corrente)
        var lancs: [Lancamento] = []
        for m in 0..<5 {
            lancs.append(gastoEm("cart", "n\(m)", data(2026, 10 - m, 8), "NETFLIX.COM", 5_590, categoria: "streaming"))
        }
        // Loja que repete, mas com valor que oscila demais e sem ser conta fixa por natureza: não vira fixo.
        for (m, v) in [10_000, 14_000, 10_000, 14_000].enumerated() {
            lancs.append(gastoEm("cc", "l\(m)", data(2026, 10 - m, 9), "BARBEARIA DO ZE", v))
        }
        let rec = Analise.recorrentes(lancamentos: lancs, contas: [cartao, cc], hoje: hoje)
        XCTAssertEqual(rec.count, 2)
        let netflix = rec.first { $0.id.contains("netflix") }!
        XCTAssertEqual(netflix.ocorrenciasPorMes.count, 5)
        XCTAssertEqual(netflix.ocorrenciasPorMes.first?.mes, "2026-06")
        XCTAssertEqual(netflix.diaTipico, 8)
        XCTAssertEqual(netflix.valorTipico, 5_590)
        XCTAssertEqual(netflix.variacao, 0)
        XCTAssertEqual(netflix.contaID, "cart")

        let v = Fixos.varrer(recorrentes: rec, fixos: [], contas: [cartao, cc], lancamentos: lancs, hoje: hoje)
        XCTAssertEqual(v.novos.count, 1, "a loja que oscila fica de fora")
        let novo = v.novos[0]
        XCTAssertEqual(novo.nome, "Netflix.com")
        XCTAssertEqual(novo.padrao, "netflix", "\"com\" não identifica loja")
        XCTAssertEqual(novo.forma, .cartao)
        XCTAssertEqual(novo.contaID, "cart")
        XCTAssertEqual(novo.diaTipico, 8)
        XCTAssertEqual(novo.valorCentavos, 5_590)
        XCTAssertTrue(novo.automatico)
        XCTAssertEqual(novo.categoriaChave, "streaming")

        // Desativado pelo usuário: não volta. Ativo com padrão parecido: também não duplica.
        let desativado = Fixo(nome: "Netflix", valorCentavos: 5_590, padrao: "netflix")
        desativado.ativo = false
        XCTAssertTrue(Fixos.varrer(recorrentes: rec, fixos: [desativado], contas: [cartao], lancamentos: lancs, hoje: hoje).novos.isEmpty)
        let streaming = Fixo(nome: "Streaming", valorCentavos: 5_000, categoriaChave: "streaming", acumula: true)
        XCTAssertTrue(Fixos.varrer(recorrentes: rec, fixos: [streaming], contas: [cartao], lancamentos: lancs, hoje: hoje).novos.isEmpty,
                      "fixo que soma a categoria já cobre")
    }

    func testVarreduraCriaContaFixaMesmoComValorOscilando() {
        let cc = Conta(externalID: "cc", nome: "Conta", tipo: .corrente)
        let lancs = [21_000, 26_500, 19_800, 24_000].enumerated().map { m, v in
            gastoEm("cc", "e\(m)", data(2026, 10 - m, 15), "ENEL DISTRIBUICAO SP", v, categoria: "luz")
        }
        let rec = Analise.recorrentes(lancamentos: lancs, contas: [cc], hoje: hoje)
        let v = Fixos.varrer(recorrentes: rec, fixos: [], contas: [cc], lancamentos: lancs, hoje: hoje)
        XCTAssertEqual(v.novos.count, 1)
        XCTAssertEqual(v.novos[0].forma, .debito)
        XCTAssertEqual(v.novos[0].diaTipico, 15)
    }

    func testVarreduraCompletaContaEDiaDoFixoExistente() {
        let cc = Conta(externalID: "cc", nome: "Conta", tipo: .corrente)
        let luz = Fixo(nome: "Luz", valorCentavos: 20_000, forma: .debito, padrao: "enel")
        let lancs = (0..<3).map { m in gastoEm("cc", "e\(m)", data(2026, 10 - m, 15), "ENEL DISTRIBUICAO", 21_000 + m) }
        let v = Fixos.varrer(recorrentes: [], fixos: [luz], contas: [cc], lancamentos: lancs, hoje: hoje)
        XCTAssertEqual(v.enriquecidos, [EnriquecimentoFixo(uid: luz.uid, contaID: "cc", diaTipico: 15)])

        luz.contaID = "cc"
        luz.diaTipico = 15
        XCTAssertTrue(Fixos.varrer(recorrentes: [], fixos: [luz], contas: [cc], lancamentos: lancs, hoje: hoje).enriquecidos.isEmpty)
    }

    func testDataDeDebitoUsaAFaturaQueContemACompra() {
        let c = cartao(fechamento: data(2026, 9, 25), vencimento: data(2026, 10, 2))
        let faturas = [
            fatura("f1", fechamento: data(2026, 8, 25), vencimento: data(2026, 9, 2)),
            fatura("f2", fechamento: data(2026, 9, 25), vencimento: data(2026, 10, 2)),
        ]
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 9, 20), conta: c, faturas: faturas), data(2026, 10, 2))
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 9, 25), conta: c, faturas: faturas), data(2026, 10, 2), "no dia do fechamento ainda entra")
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 8, 10), conta: c, faturas: faturas), data(2026, 9, 2))
        // Depois da última fatura conhecida: repete o ciclo do cartão.
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 9, 26), conta: c, faturas: faturas), data(2026, 11, 2))
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 10, 18), conta: c, faturas: faturas), data(2026, 11, 2))
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 10, 26), conta: c, faturas: faturas), data(2026, 12, 2))
        // Sem fatura nenhuma, só o ciclo.
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 10, 18), conta: c, faturas: []), data(2026, 11, 2))
        // Sem ciclo conhecido, mas com fatura antiga: o ciclo vem dela.
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 10, 18), conta: cartao(), faturas: faturas), data(2026, 11, 2))
        XCTAssertNil(Faturas.dataDeDebito(compra: data(2026, 10, 18), conta: cartao(), faturas: []))
    }

    func testDataDeDebitoCuidaDoDia31EDoVencimentoNoMesmoMes() {
        // Fecha dia 31, vence dia 7: em fevereiro fecha no último dia.
        let c = cartao(fechamento: data(2026, 8, 31), vencimento: data(2026, 9, 7))
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2027, 2, 15), conta: c, faturas: []), data(2027, 3, 7))
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 10, 31), conta: c, faturas: []), data(2026, 11, 7))
        // Fecha dia 5, vence dia 15 do mesmo mês.
        let d = cartao(fechamento: data(2026, 9, 5), vencimento: data(2026, 9, 15))
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 10, 3), conta: d, faturas: []), data(2026, 10, 15))
        XCTAssertEqual(Faturas.dataDeDebito(compra: data(2026, 10, 6), conta: d, faturas: []), data(2026, 11, 15))
    }

    func testSituacaoDizDeOndeSaiEQuandoDebita() {
        let c = cartao(fechamento: data(2026, 9, 25), vencimento: data(2026, 10, 2))
        let cc = Conta(externalID: "cc", nome: "Conta Corrente", tipo: .corrente)
        let netflix = Fixo(nome: "Netflix", valorCentavos: 5_590, forma: .cartao, padrao: "netflix")
        let claude = Fixo(nome: "Claude", valorCentavos: 50_000, forma: .cartao, padrao: "claude", contaID: "cart", diaTipico: 20)
        let luz = Fixo(nome: "Luz", valorCentavos: 20_000, forma: .debito, padrao: "enel", diaTipico: 15)
        let lancs = [
            gastoEm("cart", "n", data(2026, 10, 8), "NETFLIX", 5_590),
            gastoEm("cc", "e1", data(2026, 9, 15), "ENEL", 21_000),
        ]
        let s = Fixos.situacao(fixos: [netflix, claude, luz], marcas: [], lancamentos: lancs, mes: hoje,
                               contas: [c, cc], faturas: [], hoje: hoje)

        XCTAssertTrue(s[0].pago)
        XCTAssertEqual(s[0].contaID, "cart", "conta do lançamento casado")
        XCTAssertEqual(s[0].contaNome, "Cartão Azul")
        XCTAssertEqual(s[0].previsaoDebito, data(2026, 11, 2), "comprou dia 8, fatura fecha 25, debita dia 2")
        XCTAssertEqual(s[0].origemPrevisao, .fatura)

        XCTAssertFalse(s[1].pago)
        XCTAssertEqual(s[1].diaTipico, 20)
        XCTAssertEqual(s[1].previsaoDebito, data(2026, 11, 2), "ainda não cobrou: estima a compra no dia 20 e cai na mesma fatura")
        XCTAssertEqual(s[1].origemPrevisao, .fatura)

        XCTAssertFalse(s[2].pago)
        XCTAssertEqual(s[2].contaID, "cc", "sem cobrança no mês, vale de onde costuma sair")
        XCTAssertEqual(s[2].previsaoDebito, data(2026, 10, 15))
        XCTAssertEqual(s[2].origemPrevisao, .diaTipico)

        // Já passou do dia e não pagou: a previsão vai para o mês que vem.
        let depois = Fixos.situacao(fixos: [luz], marcas: [], lancamentos: lancs, mes: hoje, contas: [cc], hoje: data(2026, 10, 20))
        XCTAssertEqual(depois[0].previsaoDebito, data(2026, 11, 15))

        // Sem contas conhecidas, os campos ficam vazios e nada quebra.
        let semContas = Fixos.situacao(fixos: [netflix], marcas: [], lancamentos: lancs, mes: hoje)
        XCTAssertEqual(semContas[0].contaID, "cart")
        XCTAssertNil(semContas[0].contaNome)
        XCTAssertNil(semContas[0].previsaoDebito)
    }

    func testHistoricoTrazDozeMesesEUmaCobrancaPorMes() {
        let spotify = Fixo(nome: "Spotify", valorCentavos: 2_390, padrao: "spotify")
        var lancs: [Lancamento] = []
        for m in 0..<14 {
            lancs.append(gastoEm("cart", "s\(m)", Datas.somar(meses: -m, a: data(2026, 10, 3)), "SPOTIFY", 2_390))
        }
        // Uma segunda cobrança no mesmo mês (um brinde de R$ 5): fica a de valor mais próximo.
        lancs.append(gastoEm("cart", "x", data(2026, 8, 20), "SPOTIFY", 500))
        let s = Fixos.situacao(fixos: [spotify], marcas: [], lancamentos: lancs, mes: hoje)
        XCTAssertEqual(s[0].historico.count, 12)
        XCTAssertEqual(s[0].historico.first?.mes, "2025-11")
        XCTAssertEqual(s[0].historico.last?.mes, "2026-10")
        XCTAssertTrue(s[0].historico.allSatisfy { $0.valorCentavos == 2_390 })
        XCTAssertEqual(s[0].diaTipico, 3)
        XCTAssertEqual(s[0].contaID, "cart")

        // Acumula: todas as cobranças entram.
        let mercado = Fixo(nome: "Mercado", valorCentavos: 100_000, categoriaChave: "mercado", acumula: true)
        let compras = [
            gastoEm("cart", "m1", data(2026, 10, 2), "CARREFOUR", 30_000, categoria: "mercado"),
            gastoEm("cart", "m2", data(2026, 10, 9), "ASSAI", 25_000, categoria: "mercado"),
            gastoEm("cc", "m3", data(2026, 9, 28), "CARREFOUR", 99_000, categoria: "mercado"),
        ]
        let a = Fixos.situacao(fixos: [mercado], marcas: [], lancamentos: compras, mes: hoje)
        XCTAssertEqual(a[0].historico.map(\.externalID), ["m3", "m1", "m2"])
        XCTAssertEqual(a[0].contaID, "cart")
        XCTAssertNil(a[0].diaTipico, "quem soma não tem dia certo")
    }

    func testReferenciaFicaComACobrancaPertoDoCombinado() {
        // A Apple cobra várias coisas: o iCloud de R$ 19,90 não pode virar R$ 8 só porque a de R$ 8 foi a última.
        let icloud = Fixo(nome: "iCloud+", valorCentavos: 1_990, padrao: "apple")
        let ls = [
            gasto("1", data(2026, 9, 3), "APPLE", 1_990),
            gasto("2", data(2026, 9, 20), "APPLE", 800),
        ]
        let s = Fixos.situacao(fixos: [icloud], marcas: [], lancamentos: ls, mes: data(2026, 10, 5))
        XCTAssertEqual(s.first?.valorCentavos, 1_990)
        // Preço que mudou de verdade (dentro de 50%) continua valendo o último.
        let claude = Fixo(nome: "Claude", valorCentavos: 50_000, padrao: "claude")
        let s2 = Fixos.situacao(fixos: [claude], marcas: [], lancamentos: [gasto("3", data(2026, 9, 18), "CLAUDE", 47_470)], mes: data(2026, 10, 5))
        XCTAssertEqual(s2.first?.valorCentavos, 47_470)
    }
}
