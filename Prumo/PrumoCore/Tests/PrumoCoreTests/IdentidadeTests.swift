import XCTest
@testable import PrumoCore

final class IdentidadeTests: XCTestCase {
    func testForaDeUmAppValemOsPadroesGenericos() {
        XCTAssertEqual(Identidade.servicoCofre, Identidade.servicoCofrePadrao)
        XCTAssertEqual(Identidade.grupoApp, Identidade.grupoAppPadrao)
        XCTAssertEqual(Cofre.servico, "com.exemplo.prumo")
        XCTAssertEqual(SnapshotWidget.grupo, "group.com.exemplo.prumo")
    }

    func testPadroesNaoApontamParaNinguemEspecifico() {
        XCTAssertTrue(Identidade.servicoCofrePadrao.hasPrefix("com.exemplo."))
        XCTAssertTrue(Identidade.grupoAppPadrao.hasPrefix("group.com.exemplo."))
    }
}
