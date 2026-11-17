import XCTest
@testable import PrumoCore

/// Quanto a carteira rende: escala das taxas da Pluggy e o total estimado.
@MainActor
final class RendimentoTests: XCTestCase {

    private func inv(_ id: String, saldo: Int, aplicado: Int? = nil, mes: Double? = nil, doze: Double? = nil,
                     ativo: Bool = true) -> Investimento {
        let i = Investimento(externalID: id, nome: id, classe: .rendaFixa, saldoCentavos: saldo)
        i.aplicadoCentavos = aplicado
        i.rentabilidadeMes = mes
        i.rentabilidade12m = doze
        i.ativo = ativo
        return i
    }

    func testTaxasDaPluggyChegamEmPercentualEViramFracao() throws {
        let json = #"{"id":"x","name":"CDB","type":"FIXED_INCOME","subtype":"CDB","balance":1000,"annualRate":11.8,"lastMonthRate":0.9,"lastTwelveMonthsRate":11.2}"#
        let dto = try JSONDecoder().decode(PluggyInvestimento.self, from: Data(json.utf8))
        let m = Mapeador.investimento(dto)
        XCTAssertEqual(try XCTUnwrap(m.taxaAnual), 0.118, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(m.rentabilidade12m), 0.112, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(m.rentabilidadeMes), 0.009, accuracy: 1e-9)
    }

    func testSemTaxaContinuaSemTaxa() throws {
        let json = #"{"id":"x","name":"Ação","type":"EQUITY","subtype":"STOCK","balance":1000}"#
        let m = Mapeador.investimento(try JSONDecoder().decode(PluggyInvestimento.self, from: Data(json.utf8)))
        XCTAssertNil(m.taxaAnual)
        XCTAssertNil(m.rentabilidade12m)
        XCTAssertNil(m.rentabilidadeMes)
    }

    func testRendimentoDaCarteira() {
        let a = inv("A", saldo: 1_010_000, aplicado: 1_000_000, mes: 0.01, doze: 0.12)
        let b = inv("B", saldo: 500_000, doze: 0.10)                                  // sem custo e sem taxa do mês
        let c = inv("C", saldo: 9_999_999, aplicado: 1, mes: 0.5, doze: 0.5, ativo: false)   // inativo: ignorado
        let d = inv("D", saldo: 100_000, mes: 1.5, doze: 50.0)                         // taxas absurdas: ignoradas
        let r = Analise.rendimentoCarteira([a, b, c, d])

        XCTAssertEqual(r.totalInvestimentos, 3)
        XCTAssertEqual(r.saldoCentavos, 1_610_000)

        // Desde que aplicou: só quem informa o custo.
        XCTAssertEqual(r.aplicadoCentavos, 1_000_000)
        XCTAssertEqual(r.resultadoCentavos, 10_000)
        XCTAssertEqual(try XCTUnwrap(r.resultadoPercentual), 0.01, accuracy: 1e-9)

        // Mês: só o A. 1.010.000 − 1.010.000/1,01 = 10.000.
        XCTAssertEqual(r.mesCentavos, 10_000)
        XCTAssertEqual(try XCTUnwrap(r.mesPercentual), 0.01, accuracy: 1e-9)
        XCTAssertEqual(r.mesCobertos, 1)

        // 12 meses: A e B (o D foi ignorado por taxa fora do plausível).
        XCTAssertEqual(r.dozeMesesCobertos, 2)
        XCTAssertEqual(r.dozeMesesCentavos, 153_669)
        XCTAssertEqual(try XCTUnwrap(r.dozeMesesPercentual), 0.1133, accuracy: 0.0001)
    }

    func testCarteiraVaziaNaoInventaNumero() {
        let r = Analise.rendimentoCarteira([])
        XCTAssertEqual(r.saldoCentavos, 0)
        XCTAssertNil(r.resultadoPercentual)
        XCTAssertNil(r.mesCentavos)
        XCTAssertNil(r.dozeMesesCentavos)
        XCTAssertEqual(r.mesCobertos, 0)
    }

    func testPrejuizoAparece() {
        let a = inv("A", saldo: 900_000, aplicado: 1_000_000, mes: -0.02)
        let r = Analise.rendimentoCarteira([a])
        XCTAssertEqual(r.resultadoCentavos, -100_000)
        XCTAssertEqual(try XCTUnwrap(r.resultadoPercentual), -0.10, accuracy: 1e-9)
        XCTAssertLessThan(try XCTUnwrap(r.mesCentavos), 0)
    }
}
