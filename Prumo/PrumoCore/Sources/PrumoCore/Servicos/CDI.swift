import Foundation

/// O CDI de cada mês, para comparar com o rendimento da carteira.
public struct TabelaCDI: Codable, Sendable, Equatable {
    /// "2026-09" → 0,0108 (fração: 1,08% no mês).
    public var porMes: [String: Double]
    public var buscadoEm: Date

    public init(porMes: [String: Double], buscadoEm: Date) {
        self.porMes = porMes
        self.buscadoEm = buscadoEm
    }

    /// CDI de um mês (o mês corrente vem parcial: é o acumulado até o último dia útil).
    public func taxa(_ mes: Date) -> Double? { porMes[Fixos.chaveMes(mes)] }

    /// CDI acumulado nos `meses` meses que terminam em `mes` (inclusive). Nil se faltar algum mês.
    public func acumulado(meses: Int, ate mes: Date) -> Double? {
        let fim = Datas.inicioDoMes(mes)
        var fator = 1.0
        for i in 0..<meses {
            guard let t = taxa(Datas.somar(meses: -i, a: fim)) else { return nil }
            fator *= 1 + t
        }
        return fator - 1
    }
}

public enum CDIErro: Error, Sendable, Equatable {
    case semDados
    case servidor(Int)
}

/// Busca o CDI na página de dados abertos do Banco Central (série 4391: CDI acumulado no mês).
/// É uma consulta pública: nada do usuário é enviado.
public enum CDI {
    public static let endereco = URL(string: "https://api.bcb.gov.br/dados/serie/bcdata.sgs.4391/dados/ultimos/20?formato=json")!
    static let chaveCache = "prumo.cdi.tabela"

    private struct Ponto: Decodable {
        let data: String
        let valor: String
    }

    /// Lê a resposta do Banco Central: `[{"data":"01/09/2026","valor":"1.08"}, …]`.
    public static func ler(_ dados: Data, agora: Date = Date()) throws -> TabelaCDI {
        let pontos = try JSONDecoder().decode([Ponto].self, from: dados)
        var porMes: [String: Double] = [:]
        for p in pontos {
            let partes = p.data.split(separator: "/")
            guard partes.count == 3, let mes = Int(partes[1]), let ano = Int(partes[2]),
                  (1...12).contains(mes), let v = Double(p.valor.replacingOccurrences(of: ",", with: ".")),
                  // Fora disso é dado ruim: o CDI de um mês nunca passou de alguns por cento.
                  (-0.5...10).contains(v) else { continue }
            porMes[String(format: "%04d-%02d", ano, mes)] = v / 100
        }
        guard !porMes.isEmpty else { throw CDIErro.semDados }
        return TabelaCDI(porMes: porMes, buscadoEm: agora)
    }

    public static func buscar(transporte: TransporteHTTP = URLSession.shared, agora: Date = Date()) async throws -> TabelaCDI {
        var req = URLRequest(url: endereco)
        req.timeoutInterval = 20
        let (dados, http) = try await transporte.enviar(req)
        guard (200..<300).contains(http.statusCode) else { throw CDIErro.servidor(http.statusCode) }
        return try ler(dados, agora: agora)
    }

    // MARK: Guardado no aparelho

    public static func guardado(_ defaults: UserDefaults = .standard) -> TabelaCDI? {
        guard let d = defaults.data(forKey: chaveCache) else { return nil }
        return try? JSONDecoder().decode(TabelaCDI.self, from: d)
    }

    public static func guardar(_ tabela: TabelaCDI, em defaults: UserDefaults = .standard) {
        if let d = try? JSONEncoder().encode(tabela) { defaults.set(d, forKey: chaveCache) }
    }

    /// Devolve a tabela guardada se for recente (12 h); senão busca de novo. Sem rede, fica com a guardada.
    public static func atualizar(defaults: UserDefaults = .standard, transporte: TransporteHTTP = URLSession.shared,
                                 agora: Date = Date()) async -> TabelaCDI? {
        let antiga = guardado(defaults)
        if let a = antiga, agora.timeIntervalSince(a.buscadoEm) < 12 * 3600, a.taxa(Datas.somar(meses: -1, a: agora)) != nil {
            return a
        }
        guard let nova = try? await buscar(transporte: transporte, agora: agora) else { return antiga }
        guardar(nova, em: defaults)
        return nova
    }
}
