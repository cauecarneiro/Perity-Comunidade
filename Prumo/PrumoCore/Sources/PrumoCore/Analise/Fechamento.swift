import Foundation

/// Como um investimento foi no mês, comparado com o CDI.
public enum VereditoInvestimento: String, Sendable {
    /// Rendeu o CDI ou mais (em isentos de imposto, 85% do CDI já equivale).
    case bateu
    /// Rendeu, mas menos que o CDI.
    case abaixo
    /// Fechou o mês valendo menos.
    case perdeu
    /// A instituição não informou o rendimento do mês.
    case semDados
}

public struct ItemFechamento: Identifiable, Sendable, Equatable {
    public let id: String
    public let nome: String
    public let classe: ClasseAtivo
    public let saldoCentavos: Int
    /// Quanto rendeu no mês, em reais (estimado pela taxa do mês).
    public let rendeuCentavos: Int?
    public let taxaMes: Double?
    /// 1,0 = igual ao CDI do mês.
    public let percentualDoCDI: Double?
    public let taxa12m: Double?
    public let percentualDoCDI12m: Double?
    /// LCI, LCA, CRI e CRA não pagam imposto de renda.
    public let isento: Bool
    public let veredito: VereditoInvestimento
}

/// O balanço do mês que fechou: quanto a carteira rendeu, quanto isso é do CDI e o que valeu a pena.
public struct FechamentoInvestimentos: Sendable, Equatable {
    /// Primeiro dia do mês analisado (o último que fechou).
    public let mes: Date
    public let cdiMes: Double?
    public let cdi12m: Double?
    /// Soma do que rendeu no mês nos investimentos com taxa informada.
    public let rendeuCentavos: Int?
    public let taxaMes: Double?
    public let percentualDoCDI: Double?
    public let rendeu12mCentavos: Int?
    public let taxa12m: Double?
    public let percentualDoCDI12m: Double?
    public let cobertos: Int
    public let total: Int
    public let itens: [ItemFechamento]

    public var bateram: [ItemFechamento] { itens.filter { $0.veredito == .bateu } }
    public var abaixo: [ItemFechamento] { itens.filter { $0.veredito == .abaixo } }
    public var perderam: [ItemFechamento] { itens.filter { $0.veredito == .perdeu } }
    public var semDados: [ItemFechamento] { itens.filter { $0.veredito == .semDados } }

    public var nomeDoMes: String { Datas.nomeDoMes(mes) }

    /// O veredito em uma frase.
    public var frase: String {
        guard let taxa = taxaMes, let rendeu = rendeuCentavos else {
            return "Seus investimentos não informam o rendimento do mês, então não dá para fechar \(nomeDoMes)."
        }
        let quanto = "\(Dinheiro.formatarInteiro(abs(rendeu))) (\(Self.percentual(abs(taxa), casas: 2)))"
        guard let cdi = cdiMes, let doCDI = percentualDoCDI else {
            return taxa >= 0 ? "Em \(nomeDoMes) a carteira rendeu \(quanto)." : "Em \(nomeDoMes) a carteira perdeu \(quanto)."
        }
        if taxa < 0 {
            return "Em \(nomeDoMes) a carteira perdeu \(quanto). O CDI rendeu \(Self.percentual(cdi, casas: 2))."
        }
        let pct = Self.percentual(doCDI, casas: 0)
        if doCDI >= 1 {
            return "Em \(nomeDoMes) a carteira rendeu \(quanto): \(pct) do CDI. Ganhou do CDI, que deu \(Self.percentual(cdi, casas: 2))."
        }
        return "Em \(nomeDoMes) a carteira rendeu \(quanto): \(pct) do CDI. Ficou abaixo do CDI, que deu \(Self.percentual(cdi, casas: 2))."
    }

    static func percentual(_ fracao: Double, casas: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.minimumFractionDigits = casas
        f.maximumFractionDigits = casas
        return (f.string(from: NSNumber(value: fracao * 100)) ?? "\(fracao * 100)") + "%"
    }
}

extension Analise {

    static func ehIsento(_ i: Investimento) -> Bool {
        let texto = Texto.normalizar([i.subtipo ?? "", i.nome].joined(separator: " "))
        return ["lci", "lca", "cri", "cra", "lig"].contains { Categorizador.casaPadrao(texto, $0) }
    }

    /// Fecha o último mês que terminou. Usa a taxa do mês e a de 12 meses que cada instituição informa;
    /// investimento sem taxa entra como "sem dados", não como zero. A comparação é bruta (antes do imposto).
    public static func fechamentoInvestimentos(_ investimentos: [Investimento], cdi: TabelaCDI?, hoje: Date = Date()) -> FechamentoInvestimentos {
        let mes = Datas.somar(meses: -1, a: Datas.inicioDoMes(hoje))
        let cdiMes = cdi?.taxa(mes).flatMap { $0 > 0 ? $0 : nil }
        let cdi12 = cdi?.acumulado(meses: 12, ate: mes).flatMap { $0 > 0 ? $0 : nil }
        let ativos = investimentos.filter { $0.ativo && $0.saldoCentavos > 0 }

        var itens: [ItemFechamento] = []
        for i in ativos {
            let taxaMes = i.rentabilidadeMes.flatMap { (-0.5...1.0).contains($0) ? $0 : nil }
            let taxa12 = i.rentabilidade12m.flatMap { (-0.9...5.0).contains($0) ? $0 : nil }
            let isento = ehIsento(i)
            let rendeu = taxaMes.map { r -> Int in
                let atual = Double(i.saldoCentavos)
                return Int((atual - atual / (1 + r)).rounded())
            }
            let doCDI = taxaMes.flatMap { r in cdiMes.map { r / $0 } }
            let doCDI12 = taxa12.flatMap { r in cdi12.map { r / $0 } }
            let veredito: VereditoInvestimento
            if let r = taxaMes {
                if r < 0 {
                    veredito = .perdeu
                } else if let c = cdiMes {
                    veredito = r >= c * (isento ? 0.85 : 1) ? .bateu : .abaixo
                } else {
                    // Sem o CDI à mão, só dá para dizer que rendeu.
                    veredito = .bateu
                }
            } else {
                veredito = .semDados
            }
            itens.append(ItemFechamento(id: i.externalID, nome: i.nome, classe: i.classe, saldoCentavos: i.saldoCentavos,
                                        rendeuCentavos: rendeu, taxaMes: taxaMes, percentualDoCDI: doCDI,
                                        taxa12m: taxa12, percentualDoCDI12m: doCDI12, isento: isento, veredito: veredito))
        }
        // Do que mais rendeu para o que menos rendeu; sem dados por último.
        itens.sort { a, b in
            switch (a.taxaMes, b.taxaMes) {
            case let (x?, y?): return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.saldoCentavos > b.saldoCentavos
            }
        }

        let carteira = rendimentoCarteira(investimentos)
        return FechamentoInvestimentos(
            mes: mes, cdiMes: cdiMes, cdi12m: cdi12,
            rendeuCentavos: carteira.mesCentavos, taxaMes: carteira.mesPercentual,
            percentualDoCDI: carteira.mesPercentual.flatMap { r in cdiMes.map { r / $0 } },
            rendeu12mCentavos: carteira.dozeMesesCentavos, taxa12m: carteira.dozeMesesPercentual,
            percentualDoCDI12m: carteira.dozeMesesPercentual.flatMap { r in cdi12.map { r / $0 } },
            cobertos: carteira.mesCobertos, total: ativos.count, itens: itens)
    }
}
