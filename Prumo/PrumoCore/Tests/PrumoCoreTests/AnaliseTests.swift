import SwiftData
import XCTest
@testable import PrumoCore

@MainActor
final class AnaliseTests: XCTestCase {
    private let hoje = data(2026, 10, 13)
    private var container: ModelContainer!

    private func demo() throws -> (ModelContext, [Conta], [Lancamento]) {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        try DadosDemo.popular(ctx, hoje: hoje)
        return (ctx, try ctx.fetch(FetchDescriptor<Conta>()), try ctx.fetch(FetchDescriptor<Lancamento>()))
    }

    func testDemoEhCoerente() throws {
        let (ctx, contas, lancs) = try demo()
        XCTAssertEqual(contas.count, 6)
        XCTAssertGreaterThan(lancs.count, 300)
        XCTAssertTrue(DadosDemo.existe(ctx))
        // Todo lançamento cai numa categoria que existe.
        for l in lancs { XCTAssertNotNil(Categorias.todas.first { $0.chave == l.categoriaChave }, l.descricao) }
        // Nenhum gasto "do futuro" fora das parcelas pendentes.
        for l in lancs where l.data > hoje && l.origem == .demo { XCTAssertEqual(l.status, .pendente, l.descricao) }
    }

    func testInternosNaoEntramNoGasto() throws {
        let (_, contas, lancs) = try demo()
        let mes = Analise.resumoDoMes(hoje, lancamentos: lancs, contas: contas, hoje: hoje)
        let somaTudo = lancs.filter { $0.data >= Datas.inicioDoMes(hoje) && $0.data < Datas.somar(meses: 1, a: Datas.inicioDoMes(hoje)) && $0.valorCentavos < 0 }
            .reduce(0) { $0 - $1.valorCentavos }
        XCTAssertLessThan(mes.despesasCentavos, somaTudo, "pagamento de fatura e aportes ficam de fora")
        XCTAssertFalse(mes.porCategoria.contains { ["fatura", "investimentos", "transferencia"].contains($0.chave) })
        XCTAssertGreaterThan(mes.receitasCentavos, 900_000, "salário entrou")
        let soma = mes.porCategoria.reduce(0) { $0 + $1.centavos }
        XCTAssertEqual(soma, mes.despesasCentavos, "categorias fecham com o total")
    }

    func testApplePayConciliadoNaoContaEmDobro() throws {
        let (_, contas, lancs) = try demo()
        let cafes = lancs.filter { $0.descricao.hasPrefix("CAFE DO CENTRO") }
        XCTAssertEqual(cafes.count, 2)
        XCTAssertEqual(cafes.filter(\.contaParaRelatorios).count, 1)
        _ = contas
    }

    func testEstornoNoCartaoReduzOGasto() throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        let cartao = Conta(externalID: "c", nome: "Cartão", tipo: .cartao)
        ctx.insert(cartao)
        let compra = Lancamento(externalID: "1", contaID: "c", data: data(2026, 10, 2), descricao: "LOJA", valorCentavos: -10_000, origem: .openFinance)
        let estorno = Lancamento(externalID: "2", contaID: "c", data: data(2026, 10, 4), descricao: "ESTORNO LOJA", valorCentavos: 4_000, origem: .openFinance)
        estorno.categoriaChave = "compras"; compra.categoriaChave = "compras"
        [compra, estorno].forEach(ctx.insert)
        let r = Analise.resumoDoMes(hoje, lancamentos: [compra, estorno], contas: [cartao], hoje: hoje)
        XCTAssertEqual(r.despesasCentavos, 6_000)
        XCTAssertEqual(r.receitasCentavos, 0)
    }

    func testPatrimonio() throws {
        let (ctx, contas, _) = try demo()
        let invs = try ctx.fetch(FetchDescriptor<Investimento>())
        let emps = try ctx.fetch(FetchDescriptor<Emprestimo>())
        let p = Patrimonio.calcular(contas: contas, investimentos: invs, emprestimos: emps)
        let cartoes = contas.filter { $0.tipo.ehCartao }.reduce(0) { $0 + $1.saldoCentavos }
        XCTAssertEqual(p.faturasCentavos, cartoes)
        XCTAssertEqual(p.liquidoCentavos, p.disponivelCentavos + p.investidoCentavos - cartoes - 61_200 * 28)
        XCTAssertGreaterThan(p.investidoCentavos, 10_000_000)
    }

    func testAlocacaoSomaCem() throws {
        let (ctx, _, _) = try demo()
        let fatias = Analise.alocacao(try ctx.fetch(FetchDescriptor<Investimento>()))
        XCTAssertEqual(fatias.reduce(0) { $0 + $1.percentual }, 1, accuracy: 0.0001)
        XCTAssertTrue(fatias.contains { $0.classe == .cripto })
    }

    func testRecorrentesEncontraAssinaturasENaoCompras() throws {
        let (_, contas, lancs) = try demo()
        let rec = Analise.recorrentes(lancamentos: lancs, contas: contas, hoje: hoje)
        let nomes = rec.map { $0.nome.lowercased() }
        XCTAssertTrue(nomes.contains { $0.contains("netflix") }, "\(nomes)")
        XCTAssertTrue(nomes.contains { $0.contains("spotify") }, "\(nomes)")
        XCTAssertTrue(nomes.contains { $0.contains("aluguel") }, "\(nomes)")
        XCTAssertFalse(nomes.contains { $0.contains("uber") }, "corrida de aplicativo não é recorrente fixa")
        XCTAssertTrue(rec.contains { $0.ehReceita && $0.nome.lowercased().contains("salario") }, "\(nomes)")
        let gpt = rec.first { $0.nome.lowercased().contains("chatgpt") || $0.nome.lowercased().contains("openai") }
        XCTAssertNotNil(gpt?.variacaoUltima, "reajuste detectado")
    }

    func testSerieMensalTemMesesEmOrdem() throws {
        let (_, contas, lancs) = try demo()
        let s = Analise.serieMensal(lancamentos: lancs, contas: contas, meses: 6, ate: hoje)
        XCTAssertEqual(s.count, 6)
        XCTAssertEqual(s, s.sorted { $0.mes < $1.mes })
        XCTAssertTrue(s.dropLast().allSatisfy { $0.despesasCentavos > 0 })
    }

    func testPrevisaoDoMes() throws {
        let (_, contas, lancs) = try demo()
        let p = Analise.previsaoDoMes(lancamentos: lancs, contas: contas, hoje: hoje)
        XCTAssertEqual(p.diasRestantes, 18)
        XCTAssertGreaterThanOrEqual(p.projetadoCentavos, p.gastoAteHojeCentavos)
        XCTAssertGreaterThan(p.mediaMensalCentavos, 0)
    }

    func testVencimentosOrdenadosEComFaturas() throws {
        let (ctx, contas, lancs) = try demo()
        let faturas = try ctx.fetch(FetchDescriptor<Fatura>())
        let emps = try ctx.fetch(FetchDescriptor<Emprestimo>())
        let rec = Analise.recorrentes(lancamentos: lancs, contas: contas, hoje: hoje)
        let v = Analise.proximosVencimentos(contas: contas, faturas: faturas, recorrentes: rec, emprestimos: emps, hoje: hoje, dias: 14)
        XCTAssertFalse(v.isEmpty)
        XCTAssertEqual(v, v.sorted { $0.data < $1.data })
        XCTAssertTrue(v.contains { $0.tipo == .fatura })
        XCTAssertTrue(v.allSatisfy { $0.data >= Datas.inicioDoDia(hoje) })
    }

    func testOrcamentoEEstados() {
        let r = ResumoPeriodo(inicio: hoje, fim: hoje, receitasCentavos: 0, despesasCentavos: 0, quantidade: 0,
                              porCategoria: [GastoCategoria(chave: "mercado", centavos: 90_000, quantidade: 5, percentual: 1)])
        let itens = Analise.orcamento(orcamentos: [Orcamento(categoriaChave: "mercado", valorCentavos: 100_000),
                                                   Orcamento(categoriaChave: "lazer", valorCentavos: 50_000)], resumo: r)
        XCTAssertEqual(itens.first?.chave, "mercado")
        XCTAssertEqual(itens.first?.estado, .atencao)
        XCTAssertEqual(itens.last?.estado, .tranquilo)
        XCTAssertEqual(ItemOrcamento(chave: "x", limiteCentavos: 100, gastoCentavos: 120).estado, .estourado)
    }

    func testInsightsRelevantes() throws {
        let (ctx, contas, lancs) = try demo()
        let invs = try ctx.fetch(FetchDescriptor<Investimento>())
        let orcs = try ctx.fetch(FetchDescriptor<Orcamento>())
        let faturas = try ctx.fetch(FetchDescriptor<Fatura>())
        let emps = try ctx.fetch(FetchDescriptor<Emprestimo>())
        let conexoes = try ctx.fetch(FetchDescriptor<Conexao>())
        let rec = Analise.recorrentes(lancamentos: lancs, contas: contas, hoje: hoje)
        let venc = Analise.proximosVencimentos(contas: contas, faturas: faturas, recorrentes: rec, emprestimos: emps, hoje: hoje)
        let ins = Analise.insights(lancamentos: lancs, contas: contas, investimentos: invs, orcamentos: orcs, recorrentes: rec,
                                   vencimentos: venc, conexoes: conexoes, ultimaAtualizacao: hoje.addingTimeInterval(-3600), hoje: hoje)
        XCTAssertFalse(ins.isEmpty)
        XCTAssertEqual(Set(ins.map(\.id)).count, ins.count, "sem avisos repetidos")
        XCTAssertTrue(ins.contains { $0.id.hasPrefix("inv-") }, "LCI vence em 22 dias")
        let ordem: [SeveridadeInsight: Int] = [.alerta: 0, .atencao: 1, .info: 2, .positivo: 3]
        let sev = ins.map { ordem[$0.severidade]! }
        XCTAssertEqual(sev, sev.sorted(), "os mais urgentes primeiro")
    }

    func testLimparDemoNaoMexeNoQueEhReal() throws {
        let (ctx, _, _) = try demo()
        let real = Lancamento(externalID: "real-1", contaID: "r", data: hoje, descricao: "MEU GASTO", valorCentavos: -100, origem: .manual)
        let conta = Conta(externalID: "real-conta", nome: "Minha", tipo: .corrente)
        ctx.insert(real); ctx.insert(conta)
        try ctx.save()
        try DadosDemo.limpar(ctx)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Lancamento>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Conta>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<FotoPatrimonio>()), 0)
        XCTAssertFalse(DadosDemo.existe(ctx))
    }
}
