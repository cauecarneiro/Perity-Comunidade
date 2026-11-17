import Foundation

public enum PluggyErro: Error, LocalizedError, Sendable {
    case credenciaisInvalidas
    case semPermissao
    case naoEncontrado(String)
    case limiteExcedido(depoisDe: TimeInterval)
    case servidor(status: Int, mensagem: String)
    case rede(String)
    case resposta(String)

    public var errorDescription: String? {
        switch self {
        case .credenciaisInvalidas: "Client ID ou Client Secret da Pluggy inválidos."
        case .semPermissao: "A Pluggy recusou o acesso. Confira se o conector MeuPluggy está ativo na sua aplicação."
        case .naoEncontrado(let o): "A Pluggy não encontrou \(o)."
        case .limiteExcedido: "Muitas consultas seguidas à Pluggy. Tente de novo em instantes."
        case .servidor(let s, let m): "Erro \(s) da Pluggy: \(m)"
        case .rede(let m): "Sem conexão com a Pluggy: \(m)"
        case .resposta(let m): "Resposta inesperada da Pluggy: \(m)"
        }
    }
}

public struct PluggyCredenciais: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let clientID: String
    public let clientSecret: String
    public init(clientID: String, clientSecret: String) {
        self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public var estaCompleta: Bool { !clientID.isEmpty && !clientSecret.isEmpty }
    // Nunca deixa o segredo vazar em log.
    public var description: String { "PluggyCredenciais(clientID: \(clientID.prefix(6))…, clientSecret: ••••)" }
    public var debugDescription: String { description }
}

public protocol TransporteHTTP: Sendable {
    func enviar(_ requisicao: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: TransporteHTTP {
    public func enviar(_ requisicao: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, resposta) = try await self.data(for: requisicao)
        guard let http = resposta as? HTTPURLResponse else { throw PluggyErro.resposta("sem HTTP") }
        return (data, http)
    }
}

/// Cliente mínimo da API da Pluggy. Somente leitura: nunca cria, altera nem apaga nada no banco.
public actor PluggyClient {
    public static let urlBase = URL(string: "https://api.pluggy.ai")!

    private let credenciais: PluggyCredenciais
    private let transporte: TransporteHTTP
    private let base: URL
    private let agora: @Sendable () -> Date
    private let dormir: @Sendable (TimeInterval) async -> Void
    private let decoder = PluggyJSON.decoder()
    private var chave: (valor: String, expiraEm: Date)?

    public init(credenciais: PluggyCredenciais,
                transporte: TransporteHTTP = URLSession.shared,
                base: URL = PluggyClient.urlBase,
                agora: @escaping @Sendable () -> Date = { Date() },
                dormir: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }) {
        self.credenciais = credenciais
        self.transporte = transporte
        self.base = base
        self.agora = agora
        self.dormir = dormir
    }

    // MARK: Autenticação (a chave vale 2 h; renovamos aos 100 min)

    private func chaveDeApi(forcar: Bool = false) async throws -> String {
        if !forcar, let c = chave, c.expiraEm > agora() { return c.valor }
        guard credenciais.estaCompleta else { throw PluggyErro.credenciaisInvalidas }
        var req = URLRequest(url: base.appendingPathComponent("auth"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(["clientId": credenciais.clientID, "clientSecret": credenciais.clientSecret])
        let (data, http) = try await executar(req)
        switch http.statusCode {
        case 200..<300:
            struct R: Decodable { let apiKey: String }
            guard let r = try? decoder.decode(R.self, from: data) else { throw PluggyErro.resposta("auth sem apiKey") }
            chave = (r.apiKey, agora().addingTimeInterval(100 * 60))
            return r.apiKey
        case 400, 401, 403: throw PluggyErro.credenciaisInvalidas
        default: throw PluggyErro.servidor(status: http.statusCode, mensagem: Self.mensagem(data))
        }
    }

    // MARK: Requisição base (renova a chave 1x, respeita 429, repete 5xx)

    private func executar(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do { return try await transporte.enviar(req) }
        catch let e as PluggyErro { throw e }
        catch { throw PluggyErro.rede(error.localizedDescription) }
    }

    private func obter<T: Decodable>(_ caminho: String, consulta: [URLQueryItem] = [], urlCompleta: URL? = nil) async throws -> T {
        var renovou = false
        var tentativas = 0
        while true {
            var url = urlCompleta ?? base.appendingPathComponent(caminho)
            if urlCompleta == nil, !consulta.isEmpty {
                var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                comp.queryItems = consulta
                url = comp.url!
            }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue(try await chaveDeApi(forcar: renovou), forHTTPHeaderField: "X-API-KEY")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, http) = try await executar(req)
            switch http.statusCode {
            case 200..<300:
                do { return try decoder.decode(T.self, from: data) }
                catch { throw PluggyErro.resposta("\(caminho): \(error.localizedDescription)") }
            case 401, 403:
                if !renovou { renovou = true; chave = nil; continue }
                throw PluggyErro.semPermissao
            case 404:
                throw PluggyErro.naoEncontrado(caminho)
            case 429:
                let pedido = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 5
                let espera = pedido.isFinite && pedido > 0 ? pedido : 5
                tentativas += 1
                if tentativas > 2 { throw PluggyErro.limiteExcedido(depoisDe: espera) }
                await dormir(min(espera, 30))
            case 500..<600:
                tentativas += 1
                if tentativas > 2 { throw PluggyErro.servidor(status: http.statusCode, mensagem: Self.mensagem(data)) }
                await dormir(TimeInterval(tentativas))
            default:
                throw PluggyErro.servidor(status: http.statusCode, mensagem: Self.mensagem(data))
            }
        }
    }

    private static func mensagem(_ data: Data) -> String {
        struct E: Decodable { let message: String? }
        if let e = try? JSONDecoder().decode(E.self, from: data), let m = e.message { return m }
        return String(decoding: data.prefix(200), as: UTF8.self)
    }

    // MARK: Recursos

    public func item(_ id: String) async throws -> PluggyItem {
        try await obter("items/\(id)")
    }

    public func contas(itemID: String) async throws -> [PluggyConta] {
        let p: PluggyPagina<PluggyConta> = try await obter("accounts", consulta: [URLQueryItem(name: "itemId", value: itemID)])
        return p.results
    }

    /// Lançamentos de uma conta. Usa a paginação por cursor (v2); se a conta não aceitar, cai na antiga.
    public func transacoes(contaID: String, desde: Date? = nil, criadasDesde: Date? = nil) async throws -> [PluggyTransacao] {
        do {
            return try await transacoesV2(contaID: contaID, desde: desde, criadasDesde: criadasDesde)
        } catch PluggyErro.naoEncontrado {
            return try await transacoesLegado(contaID: contaID, desde: desde)
        } catch PluggyErro.servidor(let status, _) where status == 400 {
            return try await transacoesLegado(contaID: contaID, desde: desde)
        }
    }

    private func transacoesV2(contaID: String, desde: Date?, criadasDesde: Date?) async throws -> [PluggyTransacao] {
        var consulta = [URLQueryItem(name: "accountId", value: contaID)]
        if let c = criadasDesde {
            consulta.append(URLQueryItem(name: "createdAtFrom", value: Self.iso(c)))
        } else if let d = desde {
            consulta.append(URLQueryItem(name: "dateFrom", value: Self.dia(d)))
        }
        var todas: [PluggyTransacao] = []
        var pagina: PluggyPaginaCursor<PluggyTransacao> = try await obter("v2/transactions", consulta: consulta)
        todas += pagina.results
        var guarda = 0
        while let proxima = pagina.next, !proxima.isEmpty, guarda < 200 {
            guarda += 1
            guard let url = URL(string: base.absoluteString + "/v2/transactions" + proxima) else { break }
            pagina = try await obter("v2/transactions", urlCompleta: url)
            todas += pagina.results
        }
        return todas
    }

    private func transacoesLegado(contaID: String, desde: Date?) async throws -> [PluggyTransacao] {
        var todas: [PluggyTransacao] = []
        var numero = 1
        while true {
            var consulta = [URLQueryItem(name: "accountId", value: contaID),
                            URLQueryItem(name: "pageSize", value: "500"),
                            URLQueryItem(name: "page", value: String(numero))]
            if let d = desde { consulta.append(URLQueryItem(name: "from", value: Self.dia(d))) }
            let p: PluggyPagina<PluggyTransacao> = try await obter("transactions", consulta: consulta)
            todas += p.results
            if numero >= (p.totalPages ?? 1) || p.results.isEmpty || numero > 200 { break }
            numero += 1
        }
        return todas
    }

    public func faturas(contaID: String) async throws -> [PluggyFatura] {
        let p: PluggyPagina<PluggyFatura> = try await obter("bills", consulta: [URLQueryItem(name: "accountId", value: contaID)])
        return p.results
    }

    public func investimentos(itemID: String) async throws -> [PluggyInvestimento] {
        var todos: [PluggyInvestimento] = []
        var numero = 1
        while true {
            let p: PluggyPagina<PluggyInvestimento> = try await obter("investments", consulta: [
                URLQueryItem(name: "itemId", value: itemID),
                URLQueryItem(name: "pageSize", value: "500"),
                URLQueryItem(name: "page", value: String(numero)),
            ])
            todos += p.results
            if numero >= (p.totalPages ?? 1) || p.results.isEmpty || numero > 50 { break }
            numero += 1
        }
        return todos
    }

    public func emprestimos(itemID: String) async throws -> [PluggyEmprestimo] {
        let p: PluggyPagina<PluggyEmprestimo> = try await obter("loans", consulta: [URLQueryItem(name: "itemId", value: itemID)])
        return p.results
    }

    /// Saldo direto da instituição, sem esperar o ciclo de atualização. Pode não estar disponível, conforme o plano da Pluggy.
    public func saldoAgora(contaID: String) async throws -> PluggySaldo {
        try await obter("accounts/\(contaID)/balance")
    }

    // MARK: Formatação de datas da consulta

    private static func dia(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }
}
