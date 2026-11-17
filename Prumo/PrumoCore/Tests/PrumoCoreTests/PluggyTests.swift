import XCTest
@testable import PrumoCore

final class PluggyClientTests: XCTestCase {
    private let itemID = "11111111-aaaa-4aaa-8aaa-111111111111"
    private func cliente(_ t: TransporteFalso) -> PluggyClient {
        PluggyClient(credenciais: PluggyCredenciais(clientID: "id-teste", clientSecret: "segredo-teste"), transporte: t,
                     dormir: { _ in })
    }

    func testAutenticaUmaVezEEnviaChave() async throws {
        let t = servidorPluggyFalso()
        let c = cliente(t)
        _ = try await c.item(itemID)
        _ = try await c.contas(itemID: itemID)
        XCTAssertEqual(t.contar(caminho: "/auth"), 1, "a chave dura 2 h: não deve reautenticar a cada chamada")
        let comChave = t.registro.filter { $0.caminho != "/auth" }
        XCTAssertTrue(comChave.allSatisfy { $0.chave == "KEY-1" })
    }

    func testSegredoNaoVazaEmDescricao() {
        let c = PluggyCredenciais(clientID: "abcdef123456", clientSecret: "SEGREDO-SUPER-SECRETO")
        XCTAssertFalse("\(c)".contains("SEGREDO-SUPER-SECRETO"))
        XCTAssertFalse(String(reflecting: c).contains("SEGREDO-SUPER-SECRETO"))
    }

    func testPaginacaoPorCursor() async throws {
        let t = servidorPluggyFalso()
        let txs = try await cliente(t).transacoes(contaID: "acc-cc")
        XCTAssertEqual(txs.map(\.id), ["tx-1", "tx-2", "tx-3", "tx-4"])
        let pedidos = t.registro.filter { $0.caminho == "/v2/transactions" }
        XCTAssertEqual(pedidos.count, 2)
        XCTAssertEqual(pedidos[1].consulta["after"], "CURSOR2")
    }

    func testRenovaChaveUmaVezQuandoRecebe401() async throws {
        let t = TransporteFalso { r, ordem in
            switch r.caminho {
            case "/auth": return (200, Data(#"{"apiKey":"K\#(ordem)"}"#.utf8), [:])
            case "/items/x":
                return r.chave == "K1" ? (401, Data("{}".utf8), [:]) : (200, try fixture("item"), [:])
            default: return (404, Data("{}".utf8), [:])
            }
        }
        let item = try await cliente(t).item("x")
        XCTAssertEqual(item.status, "UPDATED")
        XCTAssertEqual(t.contar(caminho: "/auth"), 2)
    }

    func testRespeitaLimiteDeRequisicoes() async throws {
        let t = TransporteFalso { r, ordem in
            switch r.caminho {
            case "/auth": return (200, Data(#"{"apiKey":"K"}"#.utf8), [:])
            case "/items/x": return ordem < 3 ? (429, Data("{}".utf8), ["Retry-After": "1"]) : (200, try fixture("item"), [:])
            default: return (404, Data("{}".utf8), [:])
            }
        }
        _ = try await cliente(t).item("x")
        XCTAssertEqual(t.contar(caminho: "/items/x"), 3)
    }

    func testCaiParaApiAntigaSeV2NaoExiste() async throws {
        let t = TransporteFalso { r, _ in
            switch r.caminho {
            case "/auth": return (200, Data(#"{"apiKey":"K"}"#.utf8), [:])
            case "/v2/transactions": return (404, Data("{}".utf8), [:])
            case "/transactions":
                return (200, Data(#"{"page":1,"total":1,"totalPages":1,"results":[{"id":"t1","description":"X","amount":-1,"date":"2026-10-01T00:00:00.000Z","type":"DEBIT"}]}"#.utf8), [:])
            default: return (404, Data("{}".utf8), [:])
            }
        }
        let txs = try await cliente(t).transacoes(contaID: "a")
        XCTAssertEqual(txs.count, 1)
    }

    func testCredenciaisVaziasFalhamSemRede() async {
        let t = servidorPluggyFalso()
        let c = PluggyClient(credenciais: PluggyCredenciais(clientID: "", clientSecret: ""), transporte: t)
        do { _ = try await c.item("x"); XCTFail("deveria falhar") }
        catch PluggyErro.credenciaisInvalidas { XCTAssertEqual(t.registro.count, 0) }
        catch { XCTFail("erro inesperado: \(error)") }
    }
}

final class MapeadorTests: XCTestCase {
    private func transacoes(_ nome: String) throws -> [PluggyTransacao] {
        try PluggyJSON.decoder().decode(PluggyPaginaCursor<PluggyTransacao>.self, from: fixture(nome)).results
    }

    func testContas() throws {
        let p = try PluggyJSON.decoder().decode(PluggyPagina<PluggyConta>.self, from: fixture("accounts"))
        let cc = Mapeador.conta(p.results[0])
        XCTAssertEqual(cc.tipo, .corrente)
        XCTAssertEqual(cc.saldoCentavos, 254_037)
        XCTAssertEqual(cc.documentoTitular, "12345678909")
        let cartao = Mapeador.conta(p.results[1])
        XCTAssertEqual(cartao.tipo, .cartao)
        XCTAssertEqual(cartao.limiteCentavos, 1_000_000)
        XCTAssertEqual(cartao.disponivelCentavos, 816_945)
        XCTAssertEqual(cartao.final4, "4821")
        let venc = Datas.calendario.dateComponents([.day, .month], from: cartao.vencimento!)
        XCTAssertEqual(venc.day, 10)
        XCTAssertEqual(venc.month, 10)
    }

    func testSinaisDeCartaoEConta() throws {
        let cartao = try transacoes("transactions-card")
        let compra = Mapeador.lancamento(cartao[0], contaID: "acc-card", tipoConta: .cartao, documentoTitular: nil)
        XCTAssertEqual(compra.valorCentavos, -5590, "compra no cartão é saída")
        let pagamento = Mapeador.lancamento(cartao[1], contaID: "acc-card", tipoConta: .cartao, documentoTitular: nil)
        XCTAssertEqual(pagamento.valorCentavos, 150_000, "pagamento da fatura entra no cartão")
        let cc = try transacoes("transactions-cc-1")
        XCTAssertEqual(Mapeador.lancamento(cc[0], contaID: "acc-cc", tipoConta: .corrente, documentoTitular: nil).valorCentavos, 980_000)
        XCTAssertEqual(Mapeador.lancamento(cc[1], contaID: "acc-cc", tipoConta: .corrente, documentoTitular: nil).valorCentavos, -150_000)
    }

    func testPagamentoDeFaturaEEstornoNoCartao() throws {
        let cartao = try transacoes("transactions-card")
        let pagamento = Mapeador.lancamento(cartao[1], contaID: "acc-card", tipoConta: .cartao, documentoTitular: nil)
        let c1 = Mapeador.classificar(pagamento, tipoConta: .cartao, regras: [])
        XCTAssertTrue(c1.interno)
        XCTAssertEqual(c1.categoria, "fatura")
        let estorno = Mapeador.lancamento(cartao[2], contaID: "acc-card", tipoConta: .cartao, documentoTitular: nil)
        let c2 = Mapeador.classificar(estorno, tipoConta: .cartao, regras: [])
        XCTAssertFalse(c2.interno, "estorno devolve a compra: reduz o gasto, não é transferência")
    }

    func testParcelas() throws {
        let parcelada = Mapeador.lancamento(try transacoes("transactions-card")[3], contaID: "acc-card", tipoConta: .cartao, documentoTitular: nil)
        XCTAssertEqual(parcelada.parcelaAtual, 3)
        XCTAssertEqual(parcelada.totalParcelas, 10)
    }

    func testPixParaMimMesmoEhTransferenciaInterna() throws {
        let pix = try transacoes("transactions-cc-2")[1]
        let m = Mapeador.lancamento(pix, contaID: "acc-cc", tipoConta: .corrente, documentoTitular: "12345678909")
        XCTAssertTrue(m.transferenciaPropria)
        XCTAssertTrue(m.pendente)
        let c = Mapeador.classificar(m, tipoConta: .corrente, regras: [])
        XCTAssertTrue(c.interno)
        // Sem saber o CPF do titular, não presume nada.
        let semDoc = Mapeador.lancamento(pix, contaID: "acc-cc", tipoConta: .corrente, documentoTitular: nil)
        XCTAssertFalse(semDoc.transferenciaPropria)
    }

    func testInvestimentos() throws {
        let p = try PluggyJSON.decoder().decode(PluggyPagina<PluggyInvestimento>.self, from: fixture("investments"))
        let cdb = Mapeador.investimento(p.results[0])
        XCTAssertEqual(cdb.classe, .rendaFixa)
        XCTAssertEqual(cdb.saldoCentavos, 2_587_012)
        XCTAssertEqual(cdb.aplicadoCentavos, 2_400_000)
        XCTAssertEqual(Mapeador.investimento(p.results[1]).classe, .acoes)
        XCTAssertEqual(Mapeador.investimento(p.results[2]).classe, .fiis)
    }
}
