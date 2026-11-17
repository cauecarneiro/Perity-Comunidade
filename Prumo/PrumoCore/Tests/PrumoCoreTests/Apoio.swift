import Foundation
import XCTest
@testable import PrumoCore

func fixture(_ nome: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: nome, withExtension: "json", subdirectory: "Fixtures") else {
        throw NSError(domain: "Fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture \(nome).json não encontrada"])
    }
    return try Data(contentsOf: url)
}

struct RequisicaoRegistrada: Sendable {
    let metodo: String
    let caminho: String
    let consulta: [String: String]
    let chave: String?
}

/// Transporte HTTP falso: devolve respostas de um dicionário e registra o que foi pedido.
final class TransporteFalso: TransporteHTTP, @unchecked Sendable {
    typealias Manipulador = @Sendable (RequisicaoRegistrada, Int) throws -> (Int, Data, [String: String])

    private let trava = NSLock()
    private var _registro: [RequisicaoRegistrada] = []
    private let manipulador: Manipulador

    init(_ manipulador: @escaping Manipulador) { self.manipulador = manipulador }

    var registro: [RequisicaoRegistrada] { trava.lock(); defer { trava.unlock() }; return _registro }

    func contar(caminho: String) -> Int { registro.filter { $0.caminho == caminho }.count }

    func enviar(_ requisicao: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = requisicao.url!
        let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var consulta: [String: String] = [:]
        for q in comp.queryItems ?? [] { consulta[q.name] = q.value ?? "" }
        let r = RequisicaoRegistrada(metodo: requisicao.httpMethod ?? "GET", caminho: comp.path, consulta: consulta,
                                     chave: requisicao.value(forHTTPHeaderField: "X-API-KEY"))
        trava.lock()
        _registro.append(r)
        let ordem = _registro.filter { $0.caminho == r.caminho }.count
        trava.unlock()
        let (status, corpo, cabecalhos) = try manipulador(r, ordem)
        let resposta = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: cabecalhos)!
        return (corpo, resposta)
    }
}

/// Servidor Pluggy de mentira com os JSONs de Fixtures/.
func servidorPluggyFalso(itemID: String = "11111111-aaaa-4aaa-8aaa-111111111111", chavesEmitidas: [String] = ["KEY-1", "KEY-2", "KEY-3"]) -> TransporteFalso {
    TransporteFalso { r, ordem in
        func json(_ nome: String) throws -> (Int, Data, [String: String]) { (200, try fixture(nome), [:]) }
        switch (r.metodo, r.caminho) {
        case ("POST", "/auth"):
            let k = chavesEmitidas[min(ordem - 1, chavesEmitidas.count - 1)]
            return (200, Data(#"{"apiKey":"\#(k)"}"#.utf8), [:])
        case ("GET", "/items/\(itemID)"): return try json("item")
        case ("GET", "/accounts"): return try json("accounts")
        case ("GET", "/v2/transactions"):
            if r.consulta["accountId"] == "acc-card" { return try json("transactions-card") }
            return r.consulta["after"] == "CURSOR2" ? try json("transactions-cc-2") : try json("transactions-cc-1")
        case ("GET", "/bills"):
            return r.consulta["accountId"] == "acc-card" ? try json("bills") : (200, Data(#"{"page":1,"total":0,"totalPages":1,"results":[]}"#.utf8), [:])
        case ("GET", "/investments"): return try json("investments")
        case ("GET", "/loans"): return try json("loans")
        default: return (404, Data(#"{"message":"nao encontrado"}"#.utf8), [:])
        }
    }
}

func data(_ ano: Int, _ mes: Int, _ dia: Int, hora: Int = 12) -> Date {
    var c = DateComponents(); c.year = ano; c.month = mes; c.day = dia; c.hour = hora
    return Datas.calendario.date(from: c)!
}
