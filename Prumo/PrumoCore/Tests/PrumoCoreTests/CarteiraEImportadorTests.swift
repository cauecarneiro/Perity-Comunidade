import SwiftData
import XCTest
@testable import PrumoCore

@MainActor
final class CarteiraTests: XCTestCase {
    private var container: ModelContainer!
    private func contexto() throws -> ModelContext {
        container = try EsquemaPrumo.container(emMemoria: true)
        return container.mainContext
    }

    func testRegistraCompraELigaAoCartaoPeloFinal() throws {
        let ctx = try contexto()
        let cartao = Conta(externalID: "c1", nome: "Platinum", tipo: .cartao, instituicao: "Banco Azul")
        cartao.final4 = "4821"
        ctx.insert(cartao)
        let r = try Carteira.registrar(ctx, valorTexto: "R$ 45,90", estabelecimento: "PADARIA PAO QUENTE", cartao: "Azul Platinum ••4821")
        XCTAssertEqual(r, .registrado(tituloLancamento: "PADARIA PAO QUENTE", valorCentavos: -4590))
        let l = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Lancamento>()).first)
        XCTAssertEqual(l.contaID, "c1")
        XCTAssertEqual(l.valorCentavos, -4590)
        XCTAssertEqual(l.origem, .carteira)
        XCTAssertEqual(l.categoriaChave, "padaria")
    }

    func testToqueRepetidoEhIgnorado() throws {
        let ctx = try contexto()
        let agora = data(2026, 10, 13)
        XCTAssertEqual(try Carteira.registrar(ctx, valorTexto: "12,00", estabelecimento: "Uber", cartao: "", agora: agora),
                       .registrado(tituloLancamento: "Uber", valorCentavos: -1200))
        XCTAssertEqual(try Carteira.registrar(ctx, valorTexto: "12,00", estabelecimento: "uber", cartao: "", agora: agora.addingTimeInterval(20)), .duplicado)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Lancamento>()), 1)
        // Depois de 5 minutos é outra corrida.
        _ = try Carteira.registrar(ctx, valorTexto: "12,00", estabelecimento: "Uber", cartao: "", agora: agora.addingTimeInterval(300))
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Lancamento>()), 2)
    }

    func testValorInvalido() throws {
        let ctx = try contexto()
        XCTAssertEqual(try Carteira.registrar(ctx, valorTexto: "abc", estabelecimento: "X", cartao: ""), .valorInvalido("abc"))
        XCTAssertEqual(try Carteira.registrar(ctx, valorTexto: "0", estabelecimento: "X", cartao: ""), .valorInvalido("0"))
    }

    func testMapeamentoManualTemPrioridade() throws {
        let ctx = try contexto()
        let a = Conta(externalID: "a", nome: "A", tipo: .cartao, instituicao: "Banco X"); a.final4 = "1111"
        let b = Conta(externalID: "b", nome: "B", tipo: .cartao, instituicao: "Banco Y"); b.final4 = "2222"
        [a, b].forEach(ctx.insert)
        ctx.insert(MapaCartao(nomeCarteira: "Meu Cartão Especial", contaID: "b"))
        try ctx.save()
        _ = try Carteira.registrar(ctx, valorTexto: "10", estabelecimento: "Loja", cartao: "Meu Cartão Especial ••1111")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Lancamento>()).first?.contaID, "b")
    }
}

@MainActor
final class ImportadorTests: XCTestCase {
    private var container: ModelContainer!

    private let ofx = """
    OFXHEADER:100
    DATA:OFXSGML
    <OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>
    <STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261005120000[-3:BRT]<TRNAMT>-54.90<FITID>A1<MEMO>IFOOD *RESTAURANTE</STMTTRN>
    <STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20261005<TRNAMT>9800.00<FITID>A2<NAME>SALARIO EMPRESA XYZ</STMTTRN>
    </BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>
    """

    func testOFX() throws {
        let linhas = try Importador.ler(Data(ofx.utf8))
        XCTAssertEqual(linhas.count, 2)
        XCTAssertEqual(linhas[0].valorCentavos, -5490)
        XCTAssertEqual(linhas[0].identificador, "A1")
        XCTAssertEqual(linhas[1].descricao, "SALARIO EMPRESA XYZ")
        XCTAssertEqual(Datas.calendario.component(.day, from: linhas[0].data), 5)
    }

    func testCSVComVirgulaDecimalEPontoEVirgula() throws {
        let csv = """
        Extrato Conta Corrente
        Período;01/10/2026 a 13/10/2026

        Data Lançamento;Histórico;Descrição;Valor;Saldo
        05/10/2026;PIX RECEBIDO;CLIENTE DESIGN;1.250,00;3.000,00
        06/10/2026;COMPRA;"MERCADO, CENTRAL";-87,35;2.912,65
        """
        let linhas = try Importador.ler(Data(csv.utf8))
        XCTAssertEqual(linhas.count, 2)
        XCTAssertEqual(linhas[0].valorCentavos, 125_000)
        XCTAssertEqual(linhas[1].valorCentavos, -8735)
        XCTAssertTrue(linhas[1].descricao.contains("MERCADO, CENTRAL"))
    }

    func testCSVDeCartaoOndePositivoEhGasto() throws {
        let csv = "date,category,title,amount\n2026-10-02,restaurante,Ifood,54.90\n2026-10-03,,Estorno Loja,-20.00\n"
        let linhas = try Importador.ler(Data(csv.utf8), cartaoPositivoEhGasto: true)
        XCTAssertEqual(linhas.map(\.valorCentavos), [-5490, 2000])
    }

    func testGravacaoNaoRepeteEAceitaDuasCompraIguais() throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        let conta = Conta(externalID: "cc", nome: "CC", tipo: .corrente)
        ctx.insert(conta)
        let d = data(2026, 10, 5)
        let linhas = [
            LinhaImportada(data: d, descricao: "CAFE", valorCentavos: -1000, identificador: nil),
            LinhaImportada(data: d, descricao: "CAFE", valorCentavos: -1000, identificador: nil),
        ]
        let r1 = try Importador.gravar(linhas, em: conta, ctx)
        XCTAssertEqual(r1.novas, 2, "dois cafés iguais no mesmo dia são dois lançamentos")
        let r2 = try Importador.gravar(linhas, em: conta, ctx)
        XCTAssertEqual(r2.novas, 0)
        XCTAssertEqual(r2.repetidas, 2)
    }

    func testArquivoInvalido() {
        XCTAssertThrowsError(try Importador.ler(Data()))
        XCTAssertThrowsError(try Importador.ler(Data("isto não é extrato".utf8)))
    }
}

@MainActor
final class SnapshotWidgetTests: XCTestCase {
    private var container: ModelContainer!

    func testCalculaEIdaEVolta() throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        let hoje = data(2026, 10, 13)
        try DadosDemo.popular(ctx, hoje: hoje)
        let s = SnapshotWidget.calcular(
            lancamentos: try ctx.fetch(FetchDescriptor<Lancamento>()), contas: try ctx.fetch(FetchDescriptor<Conta>()),
            investimentos: try ctx.fetch(FetchDescriptor<Investimento>()), emprestimos: try ctx.fetch(FetchDescriptor<Emprestimo>()),
            faturas: try ctx.fetch(FetchDescriptor<Fatura>()), ocultarValores: true, demo: true, hoje: hoje)
        XCTAssertGreaterThan(s.liquidoCentavos, 0)
        XCTAssertGreaterThan(s.gastoMesCentavos, 0)
        XCTAssertGreaterThanOrEqual(s.previsaoMesCentavos, s.gastoMesCentavos)
        XCTAssertNotNil(s.proximaFaturaData, "o demo sempre tem uma fatura nos próximos 31 dias")
        XCTAssertTrue(s.ocultarValores)

        let dados = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(SnapshotWidget.self, from: dados), s)
    }
}
