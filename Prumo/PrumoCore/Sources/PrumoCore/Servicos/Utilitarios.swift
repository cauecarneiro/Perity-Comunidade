import Foundation

// MARK: - Dinheiro

/// Todo valor monetário do app é guardado em centavos (Int) para nunca acumular erro de ponto flutuante.
public enum Dinheiro {
    public static func centavos(_ reais: Double) -> Int { Int((reais * 100).rounded()) }
    public static func reais(_ centavos: Int) -> Double { Double(centavos) / 100 }

    private static func formatador(casas: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .currency
        f.currencyCode = "BRL"
        f.minimumFractionDigits = casas
        f.maximumFractionDigits = casas
        return f
    }

    /// "R$ 1.234,56"
    public static func formatar(_ centavos: Int) -> String {
        formatador(casas: 2).string(from: NSNumber(value: reais(centavos))) ?? "R$ 0,00"
    }

    /// "R$ 1.235" (sem centavos)
    public static func formatarInteiro(_ centavos: Int) -> String {
        formatador(casas: 0).string(from: NSNumber(value: reais(centavos))) ?? "R$ 0"
    }

    /// "R$ 3,2 mil", "R$ 1,4 mi" — para eixos de gráfico e espaços curtos.
    public static func formatarCompacto(_ centavos: Int) -> String {
        let v = abs(reais(centavos))
        let sinal = centavos < 0 ? "-" : ""
        func num(_ x: Double) -> String {
            let f = NumberFormatter()
            f.locale = Locale(identifier: "pt_BR")
            f.minimumFractionDigits = 0
            f.maximumFractionDigits = 1
            return f.string(from: NSNumber(value: x)) ?? "\(x)"
        }
        switch v {
        case 1_000_000...: return "\(sinal)R$ \(num(v / 1_000_000)) mi"
        case 10_000...: return "\(sinal)R$ \(num(v / 1_000)) mil"
        case 1_000...: return "\(sinal)R$ \(num(v / 1_000)) mil"
        default: return "\(sinal)R$ \(num(v))"
        }
    }

    /// Lê "R$ 45,90", "45.90", "1.234,56", "BRL 12.5" etc. Devolve centavos (sempre positivo).
    public static func ler(_ texto: String) -> Int? {
        var s = ""
        for ch in texto where ch.isNumber || ch == "," || ch == "." { s.append(ch) }
        guard !s.isEmpty, s.contains(where: { $0.isNumber }) else { return nil }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: ",."))
        let ultimaVirgula = s.lastIndex(of: ",")
        let ultimoPonto = s.lastIndex(of: ".")
        var decimalIndex: String.Index?
        switch (ultimaVirgula, ultimoPonto) {
        case let (v?, p?): decimalIndex = v > p ? v : p
        case let (v?, nil): decimalIndex = depoisDoSeparador(s, v) <= 2 ? v : nil
        case let (nil, p?): decimalIndex = depoisDoSeparador(s, p) <= 2 ? p : nil
        default: decimalIndex = nil
        }
        var inteiro = s
        var fracao = ""
        if let d = decimalIndex {
            inteiro = String(s[s.startIndex..<d])
            fracao = String(s[s.index(after: d)...])
        }
        let digitosInteiro = inteiro.filter { $0.isNumber }
        let digitosFracao = String(fracao.filter { $0.isNumber }.prefix(2))
        // Mais de 13 dígitos inteiros (R$ 10 trilhões) é lixo, e estouraria o Int ao virar centavos.
        guard digitosInteiro.count <= 13, let i = Int(digitosInteiro.isEmpty ? "0" : digitosInteiro) else { return nil }
        let f = Int(digitosFracao.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        return i * 100 + f
    }

    private static func depoisDoSeparador(_ s: String, _ idx: String.Index) -> Int {
        s.distance(from: s.index(after: idx), to: s.endIndex)
    }
}

// MARK: - Texto

public enum Texto {
    /// Minúsculas, sem acento, sem pontuação, espaços colapsados. "PÃO de Açúcar*" → "pao de acucar"
    public static func normalizar(_ s: String) -> String {
        let dobrado = s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                                locale: Locale(identifier: "pt_BR"))
        var saida = ""
        var ultimoFoiEspaco = true
        for escalar in dobrado.unicodeScalars {
            if CharacterSet.alphanumerics.contains(escalar) {
                saida.unicodeScalars.append(escalar)
                ultimoFoiEspaco = false
            } else if !ultimoFoiEspaco {
                saida.append(" ")
                ultimoFoiEspaco = true
            }
        }
        return saida.trimmingCharacters(in: .whitespaces)
    }

    private static let conectivos: Set<String> = ["de", "da", "do", "das", "dos", "e", "em", "a", "o", "no", "na", "nos", "nas", "para", "com", "por"]

    /// Caixa de título em português: "PAO DE ACUCAR" → "Pao de Acucar".
    public static func titulo(_ s: String) -> String {
        let palavras = s.lowercased().components(separatedBy: " ").filter { !$0.isEmpty }
        return palavras.enumerated().map { i, p in
            if i > 0, conectivos.contains(p) { return p }
            guard let primeira = p.first else { return p }
            return primeira.uppercased() + p.dropFirst()
        }.joined(separator: " ")
    }

    /// Só a primeira letra em maiúscula: "sábado, 10 de outubro" → "Sábado, 10 de outubro".
    public static func primeiraMaiuscula(_ s: String) -> String {
        guard let p = s.first else { return s }
        return p.uppercased() + s.dropFirst()
    }

    /// Troca qualquer valor em reais do texto por "R$ ••••" (modo ocultar valores).
    public static func ocultarDinheiro(_ s: String) -> String {
        guard let re = try? NSRegularExpression(pattern: #"[−-]?R\$\s?[−-]?[\d.]+(?:,\d+)?(?:\s(?:mil|mi))?"#) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "R$ ••••")
    }

    /// O estabelecimento por trás de uma descrição de extrato, limpo e com uma chave estável.
    public struct Loja: Equatable, Sendable {
        /// Texto normalizado sem o que não identifica a loja (adquirente, parcela, números, cidade).
        public let texto: String
        /// Trecho contíguo e curto do texto que identifica a loja ("padaria pao", "apple com bill").
        /// Vazio quando não sobra nada específico ("Pix enviado", "Compra no débito").
        public let chave: String
    }

    /// Prefixos de adquirente e carteira que escondem a loja: "PAG*GRACIE" é a Gracie, "MP *IFOOD" é o iFood.
    private static let adquirentes = try! NSRegularExpression(
        pattern: #"^\s*(pag|pg|mp|mercadopago|mercado pago|ifd|dl|ebn|ebanx|paypal|pp|picpay|stone|cielo|rede|getnet|sumup|pagseguro|pagar\.?me|zoop|adyen|stripe|iz|izettle|ton|safrapay|apple pay|google pay|samsung pay)\s*\*\s*"#,
        options: [.caseInsensitive])

    /// Parcelas ("03/12", "PARC 4/10"), CPF/CNPJ mascarados e datas.
    private static let codigos = try! NSRegularExpression(
        pattern: #"\b\d{1,2}\s*/\s*\d{1,2}\b|\b\d{2,3}\.?\*{2,}\.?\d{0,3}[-.]?\d{0,2}\b|\*{3,}\d*|\b\d{2}/\d{2}(/\d{2,4})?\b|\b\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}\b"#)

    private static let ufs: Set<String> = ["ac", "al", "ap", "am", "ba", "ce", "df", "es", "go", "ma", "mt", "ms", "mg", "pa",
                                           "pb", "pr", "pe", "pi", "rj", "rn", "rs", "ro", "rr", "sc", "sp", "se", "to"]

    /// Cidades que os cartões colocam no fim ("SAO PAULO BR", "RIO DE JANEI"); só saem quando sobra algo antes.
    private static let cidades: [[String]] = [
        ["sao", "paulo"], ["rio", "de", "janeiro"], ["rio", "de", "janei"], ["belo", "horizonte"], ["porto", "alegre"],
        ["curitiba"], ["brasilia"], ["salvador"], ["fortaleza"], ["recife"], ["goiania"], ["campinas"], ["florianopolis"],
        ["niteroi"], ["osasco"], ["guarulhos"], ["sorocaba"], ["barueri"], ["santo", "andre"], ["sao", "bernardo"],
        ["jundiai"], ["ribeirao", "preto"], ["uberlandia"], ["londrina"], ["joinville"], ["vitoria"], ["manaus"],
        ["belem"], ["natal"], ["maceio"], ["cuiaba"], ["campo", "grande"], ["teresina"], ["aracaju"], ["joao", "pessoa"],
        ["sao", "jose", "dos", "campos"], ["sao", "luis"], ["santos"],
    ]

    /// Limpa a descrição (ou o nome do estabelecimento, quando existe) e tira dela a chave da loja.
    public static func estabelecimento(_ descricao: String, _ estabelecimento: String? = nil) -> Loja {
        let origem = estabelecimento?.isEmpty == false ? estabelecimento! : descricao
        var bruto = nomeExibicao(origem)
        bruto = adquirentes.stringByReplacingMatches(in: bruto, range: NSRange(bruto.startIndex..., in: bruto), withTemplate: "")
        bruto = codigos.stringByReplacingMatches(in: bruto, range: NSRange(bruto.startIndex..., in: bruto), withTemplate: " ")
        var palavras = normalizar(bruto).split(separator: " ").map(String.init)
            .filter { !$0.allSatisfy(\.isNumber) }

        // País, cidade e UF no fim, só quando não é tudo que sobrou.
        while palavras.count > 1, let fim = palavras.last, ["br", "bra", "brasil", "brazil"].contains(fim) { palavras.removeLast() }
        if palavras.count > 1, let uf = palavras.last, ufs.contains(uf) { palavras.removeLast() }
        for cidade in cidades where palavras.count > cidade.count && Array(palavras.suffix(cidade.count)) == cidade {
            palavras.removeLast(cidade.count)
            if palavras.count > 1, let uf = palavras.last, ufs.contains(uf) { palavras.removeLast() }
            break
        }

        let texto = palavras.joined(separator: " ")
        // Chave: do primeiro ao segundo termo específico, com o que houver entre eles, para continuar sendo um
        // trecho do texto normalizado ("apple com bill", não "apple bill").
        func especifica(_ p: String) -> Bool { p.count > 2 && !Categorizador.palavrasGenericas.contains(p) }
        guard let inicio = palavras.firstIndex(where: especifica) else { return Loja(texto: texto, chave: "") }
        let resto = palavras[(inicio + 1)...]
        let fim = resto.firstIndex(where: especifica) ?? inicio
        return Loja(texto: texto, chave: palavras[inicio...fim].joined(separator: " "))
    }

    /// Remove prefixos que os bancos colocam ("COMPRA NO DEBITO - ") e põe em caixa de título.
    public static func nomeExibicao(_ bruto: String) -> String {
        var s = bruto.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixos = [
            "compra no debito", "compra no débito", "compra com cartao", "compra com cartão",
            "compra cartao", "compra cartão", "compra debito", "compra débito", "compra credito", "compra crédito",
            "pagamento efetuado", "pagamento pix", "pix enviado", "pix recebido", "pix transferencia",
            "transferencia enviada", "transferência enviada", "transferencia recebida", "transferência recebida",
            "pgto", "pag*", "pg *", "pagto",
        ]
        let minuscula = s.lowercased()
        for p in prefixos where minuscula.hasPrefix(p) {
            s = String(s.dropFirst(p.count))
            break
        }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " -:*·–—"))
        if s.isEmpty { s = bruto }
        // Só reformata quando vem tudo em maiúsculas (padrão de extrato).
        if s == s.uppercased(), s.rangeOfCharacter(from: .lowercaseLetters) == nil {
            s = titulo(s)
        }
        return s
    }
}

// MARK: - Datas

public enum Datas {
    /// Calendário do app (gregoriano, pt-BR, fuso do aparelho). Criado uma vez: montar um `Calendar` custa
    /// caro e as análises pedem o calendário milhares de vezes.
    public static let calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "pt_BR")
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }()

    /// A Pluggy manda a data do lançamento como meia-noite UTC ("2025-06-11T00:00:00.000Z"),
    /// que é só um *dia*. Em fuso -03:00 isso viraria o dia anterior. Aqui o dia é preservado
    /// e a hora vai para o meio-dia local, longe de qualquer virada de dia.
    public static func diaCivil(deUTC data: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = utc.dateComponents([.year, .month, .day], from: data)
        var comp = DateComponents()
        comp.year = c.year; comp.month = c.month; comp.day = c.day; comp.hour = 12
        return calendario.date(from: comp) ?? data
    }

    public static func inicioDoMes(_ d: Date) -> Date {
        let cal = calendario
        return cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
    }

    public static func inicioDoDia(_ d: Date) -> Date { calendario.startOfDay(for: d) }

    public static func somar(meses: Int, a d: Date) -> Date {
        calendario.date(byAdding: .month, value: meses, to: d) ?? d
    }

    public static func somar(dias: Int, a d: Date) -> Date {
        calendario.date(byAdding: .day, value: dias, to: d) ?? d
    }

    /// "setembro"
    public static func nomeDoMes(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendario
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "LLLL"
        return f.string(from: d)
    }

    public static func dias(de a: Date, ate b: Date) -> Int {
        calendario.dateComponents([.day], from: inicioDoDia(a), to: inicioDoDia(b)).day ?? 0
    }
}
