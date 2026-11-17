import Foundation
import SwiftData

public struct LinhaImportada: Sendable, Equatable {
    public var data: Date
    public var descricao: String
    /// Com sinal: negativo = saiu.
    public var valorCentavos: Int
    public var identificador: String?
}

public enum ErroImportacao: Error, LocalizedError, Equatable {
    case arquivoVazio
    case formatoNaoReconhecido
    case semColunas(String)

    public var errorDescription: String? {
        switch self {
        case .arquivoVazio: "O arquivo está vazio."
        case .formatoNaoReconhecido: "Não consegui reconhecer o formato. Use um extrato em OFX ou CSV."
        case .semColunas(let f): "Não achei as colunas de data, descrição e valor (\(f))."
        }
    }
}

/// Lê extratos em OFX e CSV, para bancos fora do limite de conexões do Meu Pluggy.
public enum Importador {

    public static func ler(_ dados: Data, cartaoPositivoEhGasto: Bool = false) throws -> [LinhaImportada] {
        guard !dados.isEmpty else { throw ErroImportacao.arquivoVazio }
        let texto = decodificar(dados)
        if texto.range(of: "<STMTTRN>", options: .caseInsensitive) != nil || texto.uppercased().contains("OFXHEADER") {
            return lerOFX(texto, positivoEhGasto: cartaoPositivoEhGasto)
        }
        return try lerCSV(texto, positivoEhGasto: cartaoPositivoEhGasto)
    }

    private static func decodificar(_ d: Data) -> String {
        if let s = String(data: d, encoding: .utf8) { return s }
        if let s = String(data: d, encoding: .isoLatin1) { return s }
        return String(decoding: d, as: UTF8.self)
    }

    // MARK: OFX

    static func lerOFX(_ textoOriginal: String, positivoEhGasto: Bool = false) -> [LinhaImportada] {
        // Tags em minúsculas também existem em arquivos de alguns bancos.
        let texto = textoOriginal
            .replacingOccurrences(of: "<stmttrn>", with: "<STMTTRN>", options: .caseInsensitive)
        var linhas: [LinhaImportada] = []
        let blocos = texto.components(separatedBy: "<STMTTRN>").dropFirst()
        for bloco in blocos {
            let fim = bloco.range(of: "</STMTTRN>", options: .caseInsensitive)?.lowerBound ?? bloco.endIndex
            let corpo = String(bloco[bloco.startIndex..<fim])
            func tag(_ nome: String) -> String? {
                guard let r = corpo.range(of: "<\(nome)>", options: .caseInsensitive) else { return nil }
                let resto = corpo[r.upperBound...]
                let fimLinha = resto.firstIndex(where: { $0 == "<" || $0 == "\n" || $0 == "\r" }) ?? resto.endIndex
                return String(resto[resto.startIndex..<fimLinha]).trimmingCharacters(in: .whitespaces)
            }
            guard let dt = tag("DTPOSTED"), let valorTxt = tag("TRNAMT"), let data = dataOFX(dt),
                  var valor = valorComSinal(valorTxt) else { continue }   // valor ilegível: pula a linha, não vira R$ 0
            if positivoEhGasto { valor = -valor }
            let descricao = [tag("NAME"), tag("MEMO")].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            if ehLinhaDeSaldo(descricao) { continue }
            linhas.append(LinhaImportada(data: data, descricao: descricao.isEmpty ? "Lançamento" : descricao,
                                         valorCentavos: valor, identificador: tag("FITID")))
        }
        return linhas
    }

    /// "SALDO ANTERIOR", "Saldo do dia"… não são movimentações.
    static func ehLinhaDeSaldo(_ descricao: String) -> Bool {
        let n = Texto.normalizar(descricao)
        return n == "saldo" || n.hasPrefix("saldo anterior") || n.hasPrefix("saldo do dia") || n.hasPrefix("saldo final")
            || n.hasPrefix("saldo atual") || n.hasPrefix("saldo disponivel") || n.hasPrefix("saldo inicial")
    }

    /// "-1.234,56", "-1,234.56", "45,90 D", "(12,00)", "1234.56 C" → centavos com sinal. Nil se ilegível.
    static func valorComSinal(_ s: String) -> Int? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let u = t.uppercased()
        var negativo = t.contains("-") || t.contains("−") || t.hasPrefix("(")
        if let ultimo = u.last, ultimo == "D" || ultimo == "C" {
            let antes = u.dropLast().last
            if antes == nil || antes!.isNumber || antes == " " { negativo = ultimo == "D" }
        }
        guard let c = Dinheiro.ler(t) else { return nil }
        return negativo ? -c : c
    }

        private static func dataOFX(_ s: String) -> Date? {
        let digitos = s.prefix(8)
        guard digitos.count == 8, digitos.allSatisfy(\.isNumber) else { return nil }
        var c = DateComponents()
        c.year = Int(digitos.prefix(4)); c.month = Int(digitos.dropFirst(4).prefix(2)); c.day = Int(digitos.suffix(2)); c.hour = 12
        return Datas.calendario.date(from: c)
    }

    // MARK: CSV

    static func lerCSV(_ texto: String, positivoEhGasto: Bool) throws -> [LinhaImportada] {
        let linhasBrutas = texto.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard linhasBrutas.count >= 2 else { throw ErroImportacao.formatoNaoReconhecido }

        // Procura o cabeçalho nas primeiras linhas (alguns bancos põem metadados antes).
        let delimitador: Character = {
            let amostra = linhasBrutas.prefix(10).joined()
            return amostra.filter { $0 == ";" }.count >= amostra.filter { $0 == "," }.count && amostra.contains(";") ? ";" : ","
        }()
        var indiceCabecalho: Int?
        var colData = -1, colValor = -1, colId = -1, colCredito = -1, colDebito = -1
        var colsDesc: [Int] = []
        for (i, linha) in linhasBrutas.prefix(15).enumerated() {
            let c = campos(linha, delimitador).map { Texto.normalizar($0) }
            let d = c.firstIndex { $0.contains("data") || $0 == "date" }
            let v = c.firstIndex { $0.contains("valor") || $0 == "amount" || $0.contains("quantia") }
            let cred = c.firstIndex { $0.contains("credito") }
            let deb = c.firstIndex { $0.contains("debito") }
            let ds = c.indices.filter { idx in
                let n = c[idx]
                return n.contains("descri") || n.contains("historico") || n == "title" || n.contains("memo")
                    || n.contains("estabelecimento") || (n.contains("lancamento") && !n.contains("data"))
            }
            if let d, !ds.isEmpty, v != nil || (cred != nil && deb != nil) {
                indiceCabecalho = i
                colData = d; colsDesc = ds; colValor = v ?? -1; colCredito = cred ?? -1; colDebito = deb ?? -1
                colId = c.firstIndex { $0.contains("identificador") || $0 == "id" } ?? -1
                break
            }
        }
        guard let h = indiceCabecalho else { throw ErroImportacao.semColunas("CSV") }

        let corpoLinhas = Array(linhasBrutas.dropFirst(h + 1))
        let formatoAmericano = inferirFormatoAmericano(corpoLinhas.compactMap { l -> String? in
            let c = campos(l, delimitador)
            return colData < c.count ? c[colData] : nil
        })
        var saida: [LinhaImportada] = []
        for linha in corpoLinhas {
            let c = campos(linha, delimitador)
            guard c.count > max(colData, colsDesc.max() ?? 0), let data = dataCSV(c[colData], americano: formatoAmericano) else { continue }
            let descricao = colsDesc.map { c[$0] }.filter { !$0.isEmpty }.joined(separator: " ")
            var valor: Int?
            if colValor >= 0, colValor < c.count { valor = valorCSV(c[colValor]) }
            if valor == nil, colCredito >= 0, colDebito >= 0, colCredito < c.count, colDebito < c.count {
                let cr = valorCSV(c[colCredito]) ?? 0
                let db = valorCSV(c[colDebito]) ?? 0
                valor = cr != 0 ? abs(cr) : -abs(db)
            }
            guard var v = valor else { continue }
            if positivoEhGasto { v = -v }
            if ehLinhaDeSaldo(descricao) { continue }
            saida.append(LinhaImportada(data: data, descricao: descricao.isEmpty ? "Lançamento" : descricao, valorCentavos: v,
                                        identificador: colId >= 0 && colId < c.count ? c[colId] : nil))
        }
        if saida.isEmpty { throw ErroImportacao.formatoNaoReconhecido }
        return saida
    }

    /// Divide uma linha CSV respeitando aspas.
    static func campos(_ linha: String, _ delim: Character) -> [String] {
        var out: [String] = []
        var atual = ""
        var dentro = false
        for ch in linha {
            if ch == "\"" { dentro.toggle() }
            else if ch == delim && !dentro { out.append(atual.trimmingCharacters(in: .whitespaces)); atual = "" }
            else { atual.append(ch) }
        }
        out.append(atual.trimmingCharacters(in: .whitespaces))
        return out
    }

    /// Se alguma data tem o segundo número acima de 12 (e o primeiro não), o arquivo é MM/dd/aaaa.
    static func inferirFormatoAmericano(_ amostras: [String]) -> Bool {
        var primeiroMaior = false, segundoMaior = false
        for a in amostras {
            let partes = a.prefix(10).split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            guard partes.count >= 3, a.contains("/") || a.contains("-") && !(partes[0] > 1900) else { continue }
            if partes[0] > 12 { primeiroMaior = true }
            if partes[1] > 12 { segundoMaior = true }
        }
        return segundoMaior && !primeiroMaior
    }

    private static func dataCSV(_ s: String, americano: Bool) -> Date? {
        let t = s.trimmingCharacters(in: .whitespaces)
        let formatos: [String] = americano
            ? ["yyyy-MM-dd", "MM/dd/yyyy", "MM-dd-yyyy", "MM/dd/yy"]
            : ["yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "yyyy/MM/dd", "dd/MM/yy"]
        for f in formatos {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.calendar = Datas.calendario
            df.timeZone = Datas.calendario.timeZone
            df.dateFormat = f
            guard t.count >= f.count, let d = df.date(from: String(t.prefix(f.count))) else { continue }
            // "11/06/25" lido com "yyyy" viraria o ano 25; só aceita anos plausíveis.
            let ano = Datas.calendario.component(.year, from: d)
            guard (1990...2100).contains(ano) else { continue }
            return Datas.calendario.date(bySettingHour: 12, minute: 0, second: 0, of: d)
        }
        return nil
    }

    private static func valorCSV(_ s: String) -> Int? { valorComSinal(s) }

    // MARK: Gravação

    /// Grava as linhas numa conta, sem repetir o que já foi importado. Devolve (novas, repetidas).
    @discardableResult
    public static func gravar(_ linhas: [LinhaImportada], em conta: Conta, _ ctx: ModelContext) throws -> (novas: Int, repetidas: Int) {
        let contaID = conta.externalID
        let existentes = try ctx.fetch(FetchDescriptor<Lancamento>(predicate: #Predicate { $0.contaID == contaID }))
        var ids = Set(existentes.map(\.externalID))
        let regras = try ctx.fetch(FetchDescriptor<Regra>())
        let doBanco = existentes.filter { $0.origem == .openFinance }
        var novas = 0, repetidas = 0
        var contagemMesmaChave: [String: Int] = [:]

        for l in linhas {
            // A mesma compra que o Open Finance já trouxe para esta conta: não entra de novo.
            if doBanco.contains(where: { $0.valorCentavos == l.valorCentavos && abs(Datas.dias(de: $0.data, ate: l.data)) <= 1 }) {
                repetidas += 1
                continue
            }
            let base = l.identificador.map { "imp-\(contaID)-\($0)" }
                ?? "imp-\(contaID)-\(Int(l.data.timeIntervalSince1970 / 86_400))-\(l.valorCentavos)-\(Texto.normalizar(l.descricao))"
            // Duas compras idênticas no mesmo dia são legítimas: numeramos as ocorrências.
            let n = (contagemMesmaChave[base] ?? 0) + 1
            contagemMesmaChave[base] = n
            let id = n == 1 ? base : "\(base)#\(n)"
            if ids.contains(id) { repetidas += 1; continue }
            ids.insert(id)

            let lanc = Lancamento(externalID: id, contaID: contaID, data: l.data, descricao: l.descricao,
                                  valorCentavos: l.valorCentavos, origem: .importado)
            let r = Categorizador.categorizar(descricao: l.descricao, valorCentavos: l.valorCentavos,
                                              ehCartao: conta.tipo.ehCartao, regras: regras)
            lanc.categoriaChave = r.chave
            lanc.interno = r.interno
            if conta.tipo.ehCartao, l.valorCentavos > 0, r.chave != "reembolsos" { lanc.interno = true; lanc.categoriaChave = "fatura" }
            ctx.insert(lanc)
            novas += 1
        }
        try ctx.save()
        try Conciliador.conciliar(ctx)
        return (novas, repetidas)
    }
}
