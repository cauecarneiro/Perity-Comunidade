import SwiftData
import XCTest
@testable import PrumoCore

@MainActor
final class SincronizadorTests: XCTestCase {
    private let itemID = "11111111-aaaa-4aaa-8aaa-111111111111"
    private let agoraFixa = data(2026, 10, 13, hora: 14)
    /// O contexto não segura o container: se ele for liberado, o SwiftData aborta.
    private var container: ModelContainer!

    private func montar() throws -> (ModelContext, MotorDeSincronizacao, TransporteFalso) {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        ctx.insert(Conexao(itemID: itemID, nome: "Meu banco"))
        try ctx.save()
        let t = servidorPluggyFalso()
        let cliente = PluggyClient(credenciais: PluggyCredenciais(clientID: "i", clientSecret: "s"), transporte: t, dormir: { _ in })
        let agora = agoraFixa
        return (ctx, MotorDeSincronizacao(contexto: ctx, cliente: cliente, agora: { agora }), t)
    }

    func testSincronizacaoCompleta() async throws {
        let (ctx, motor, _) = try montar()
        let r = await motor.sincronizarTudo()
        XCTAssertTrue(r.erros.isEmpty, "\(r.erros)")
        XCTAssertEqual(r.lancamentosNovos, 8)

        let contas = try ctx.fetch(FetchDescriptor<Conta>())
        XCTAssertEqual(contas.count, 2)
        let cartao = try XCTUnwrap(contas.first { $0.tipo == .cartao })
        XCTAssertEqual(cartao.saldoCentavos, 183_055)
        XCTAssertEqual(cartao.instituicao, "Banco Teste")

        let conexao = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Conexao>()).first)
        XCTAssertEqual(conexao.nome, "Banco Teste", "nome vem do conector da Pluggy")
        XCTAssertEqual(conexao.status, "UPDATED")
        XCTAssertNotNil(conexao.proximaAtualizacao)

        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Fatura>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Investimento>()), 3)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<FotoPatrimonio>()), 1)

        let lancs = try ctx.fetch(FetchDescriptor<Lancamento>())
        func l(_ id: String) -> Lancamento { lancs.first { $0.externalID == id }! }
        XCTAssertEqual(l("tx-1").categoriaChave, "salario")
        XCTAssertFalse(l("tx-1").interno)
        XCTAssertTrue(l("tx-2").interno, "pagamento de fatura não é gasto")
        XCTAssertEqual(l("tx-3").categoriaChave, "delivery")
        XCTAssertTrue(l("tx-4").interno, "Pix para a própria conta não é gasto")
        XCTAssertEqual(l("tx-4").status, .pendente)
        XCTAssertEqual(l("ctx-1").categoriaChave, "streaming")
        XCTAssertTrue(l("ctx-2").interno)
        XCTAssertFalse(l("ctx-3").interno)
        XCTAssertEqual(l("ctx-4").parcelaAtual, 3)
        // O dia do lançamento é o dia civil, sem escorregar para o dia anterior.
        let d = Datas.calendario.dateComponents([.day], from: l("tx-1").data)
        XCTAssertEqual(d.day, 5)
    }

    func testSincronizarDuasVezesNaoDuplica() async throws {
        let (ctx, motor, _) = try montar()
        _ = await motor.sincronizarTudo()
        let r2 = await motor.sincronizarTudo()
        XCTAssertTrue(r2.erros.isEmpty, "\(r2.erros)")
        XCTAssertEqual(r2.lancamentosNovos, 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Lancamento>()), 8)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Conta>()), 2)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Investimento>()), 3)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<FotoPatrimonio>()), 1, "uma foto por dia")
    }

    func testCategoriaCorrigidaPeloUsuarioSobrevive() async throws {
        let (ctx, motor, _) = try montar()
        _ = await motor.sincronizarTudo()
        let tx = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Lancamento>()).first { $0.externalID == "tx-3" })
        tx.categoriaChave = "lazer"
        tx.categoriaManual = true
        tx.notas = "aniversário"
        try ctx.save()
        _ = await motor.sincronizarTudo()
        let depois = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Lancamento>()).first { $0.externalID == "tx-3" })
        XCTAssertEqual(depois.categoriaChave, "lazer")
        XCTAssertEqual(depois.notas, "aniversário")
    }

    func testPendenteQueSumiuDoBancoEhRemovido() async throws {
        let (ctx, motor, _) = try montar()
        // Um pendente antigo que o banco não devolve mais.
        let fantasma = Lancamento(externalID: "tx-fantasma", contaID: "acc-cc", data: data(2026, 10, 12), descricao: "COMPRA CANCELADA",
                                  valorCentavos: -999, origem: .openFinance)
        fantasma.status = .pendente
        ctx.insert(fantasma)
        try ctx.save()
        _ = await motor.sincronizarTudo()
        let ids = try ctx.fetch(FetchDescriptor<Lancamento>()).map(\.externalID)
        XCTAssertFalse(ids.contains("tx-fantasma"))
    }

    func testConexaoSemCredencialDeixaAvisoSemQuebrar() async throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let t = servidorPluggyFalso()
        let cliente = PluggyClient(credenciais: PluggyCredenciais(clientID: "i", clientSecret: "s"), transporte: t, dormir: { _ in })
        let motor = MotorDeSincronizacao(contexto: container.mainContext, cliente: cliente)
        let r = await motor.sincronizarTudo()
        XCTAssertTrue(r.erros.isEmpty)
        XCTAssertFalse(r.avisos.isEmpty)
        XCTAssertEqual(t.registro.count, 0)
    }
}

@MainActor
final class ConciliadorEHigieneTests: XCTestCase {
    private var container: ModelContainer!
    private func contexto() throws -> ModelContext {
        container = try EsquemaPrumo.container(emMemoria: true)
        return container.mainContext
    }

    func testApplePayConfirmadoPeloBancoApareceUmaVez() throws {
        let ctx = try contexto()
        let pay = Lancamento(externalID: "w1", contaID: "", data: data(2026, 10, 10), descricao: "PADARIA PAO QUENTE", valorCentavos: -1890, origem: .carteira)
        let banco = Lancamento(externalID: "b1", contaID: "acc-card", data: data(2026, 10, 11), descricao: "PADARIA PAO QUENTE LTDA", valorCentavos: -1890, origem: .openFinance)
        let outro = Lancamento(externalID: "b2", contaID: "acc-card", data: data(2026, 10, 11), descricao: "MERCADO XYZ", valorCentavos: -1890, origem: .openFinance)
        [pay, banco, outro].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 1)
        XCTAssertEqual(pay.conciliadoComID, "b1", "escolhe o parecido, não só o de mesmo valor")
        XCTAssertFalse(pay.contaParaRelatorios)
        XCTAssertTrue(banco.contaParaRelatorios)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 0, "idempotente")
    }

    func testValorDiferenteOuDataLongeNaoConcilia() throws {
        let ctx = try contexto()
        let pay = Lancamento(externalID: "w1", contaID: "", data: data(2026, 10, 1), descricao: "CAFE", valorCentavos: -1000, origem: .carteira)
        let longe = Lancamento(externalID: "b1", contaID: "a", data: data(2026, 10, 20), descricao: "CAFE", valorCentavos: -1000, origem: .openFinance)
        let diferente = Lancamento(externalID: "b2", contaID: "a", data: data(2026, 10, 2), descricao: "CAFE", valorCentavos: -1001, origem: .openFinance)
        [pay, longe, diferente].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 0)
        XCTAssertNil(pay.conciliadoComID)
    }

    func testDoisToquesIguaisCasamComDoisLancamentosDoBanco() throws {
        let ctx = try contexto()
        let a = Lancamento(externalID: "w1", contaID: "", data: data(2026, 10, 10), descricao: "UBER", valorCentavos: -2000, origem: .carteira)
        let b = Lancamento(externalID: "w2", contaID: "", data: data(2026, 10, 10), descricao: "UBER", valorCentavos: -2000, origem: .carteira)
        let x = Lancamento(externalID: "b1", contaID: "c", data: data(2026, 10, 10), descricao: "UBER *TRIP", valorCentavos: -2000, origem: .openFinance)
        let y = Lancamento(externalID: "b2", contaID: "c", data: data(2026, 10, 10), descricao: "UBER *TRIP", valorCentavos: -2000, origem: .openFinance)
        [a, b, x, y].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 2)
        XCTAssertNotEqual(a.conciliadoComID, b.conciliadoComID, "cada lançamento do banco é usado uma vez")
    }

    func testCategoriaEditadaNoProvisorioPassaParaOOficial() throws {
        let ctx = try contexto()
        let pay = Lancamento(externalID: "w1", contaID: "", data: data(2026, 10, 10), descricao: "LOJA X", valorCentavos: -5000, origem: .carteira)
        pay.categoriaChave = "presentes"; pay.categoriaManual = true
        let banco = Lancamento(externalID: "b1", contaID: "c", data: data(2026, 10, 10), descricao: "LOJA X", valorCentavos: -5000, origem: .openFinance)
        [pay, banco].forEach(ctx.insert)
        _ = try Conciliador.conciliar(ctx)
        XCTAssertEqual(banco.categoriaChave, "presentes")
        XCTAssertTrue(banco.categoriaManual)
    }

    func testDinheiroVivoManualNuncaConcilia() throws {
        let ctx = try contexto()
        let manual = Lancamento(externalID: "m1", contaID: "", data: data(2026, 10, 10), descricao: "Feira", valorCentavos: -5000, origem: .manual)
        let banco = Lancamento(externalID: "b1", contaID: "c", data: data(2026, 10, 10), descricao: "FEIRA", valorCentavos: -5000, origem: .openFinance)
        [manual, banco].forEach(ctx.insert)
        XCTAssertEqual(try Conciliador.conciliar(ctx), 0)
    }

    func testDeduplicaERespeitaEdicaoDoUsuario() throws {
        let ctx = try contexto()
        let a = Lancamento(externalID: "tx", contaID: "c", data: data(2026, 10, 1), descricao: "A", valorCentavos: -100, origem: .openFinance)
        let b = Lancamento(externalID: "tx", contaID: "c", data: data(2026, 10, 1), descricao: "A", valorCentavos: -100, origem: .openFinance)
        b.categoriaManual = true; b.categoriaChave = "lazer"
        let c1 = Conexao(itemID: "i", nome: "x"); let c2 = Conexao(itemID: "i", nome: "x")
        [a, b].forEach(ctx.insert); [c1, c2].forEach(ctx.insert)
        try ctx.save()
        XCTAssertEqual(try Higiene.deduplicar(ctx), 2)
        let restantes = try ctx.fetch(FetchDescriptor<Lancamento>())
        XCTAssertEqual(restantes.count, 1)
        XCTAssertEqual(restantes[0].categoriaChave, "lazer", "fica a cópia que você editou")
    }
}
