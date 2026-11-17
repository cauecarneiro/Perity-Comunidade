import Foundation
import SwiftData

public enum ClasseAtivo: String, CaseIterable, Sendable {
    case tesouro, rendaFixa, fundos, acoes, fiis, etfs, bdrs, previdencia, coe, cripto, outros

    public var nome: String {
        switch self {
        case .tesouro: "Tesouro Direto"
        case .rendaFixa: "Renda fixa"
        case .fundos: "Fundos"
        case .acoes: "Ações"
        case .fiis: "Fundos imobiliários"
        case .etfs: "ETFs"
        case .bdrs: "BDRs"
        case .previdencia: "Previdência"
        case .coe: "COE"
        case .cripto: "Criptomoedas"
        case .outros: "Outros"
        }
    }

    public var corHex: String {
        switch self {
        case .tesouro: "0C47F9"
        case .rendaFixa: "3E7BFA"
        case .fundos: "7C5CFC"
        case .acoes: "F5A524"
        case .fiis: "17B26A"
        case .etfs: "E5484D"
        case .bdrs: "FF7A45"
        case .previdencia: "12B5CB"
        case .coe: "A855F7"
        case .cripto: "F7931A"
        case .outros: "8B93A1"
        }
    }

    public var icone: String {
        switch self {
        case .tesouro: "building.columns.fill"
        case .rendaFixa: "percent"
        case .fundos: "square.stack.3d.up.fill"
        case .acoes: "chart.line.uptrend.xyaxis"
        case .fiis: "building.2.fill"
        case .etfs: "chart.bar.xaxis"
        case .bdrs: "globe.americas.fill"
        case .previdencia: "shield.lefthalf.filled"
        case .coe: "doc.text.fill"
        case .cripto: "bitcoinsign.circle.fill"
        case .outros: "ellipsis.circle.fill"
        }
    }

    /// Ativos de renda variável oscilam todo dia; renda fixa tem vencimento.
    public var ehRendaVariavel: Bool {
        [.acoes, .fiis, .etfs, .bdrs, .cripto].contains(self)
    }

    public static func de(type: String?, subtype: String?) -> ClasseAtivo {
        switch (type ?? "").uppercased() {
        case "FIXED_INCOME":
            return (subtype ?? "").uppercased() == "TREASURY" ? .tesouro : .rendaFixa
        case "MUTUAL_FUND": return .fundos
        case "EQUITY":
            switch (subtype ?? "").uppercased() {
            case "REAL_ESTATE_FUND": return .fiis
            case "BDR": return .bdrs
            default: return .acoes
            }
        case "ETF": return .etfs
        case "SECURITY": return .previdencia
        case "COE": return .coe
        default: return .outros
        }
    }
}

@Model
public final class Investimento {
    public var externalID: String = ""
    public var conexaoItemID: String = ""
    public var instituicao: String = ""
    public var nome: String = ""
    public var classeRaw: String = ClasseAtivo.outros.rawValue
    public var subtipo: String?
    /// Valor líquido atual.
    public var saldoCentavos: Int = 0
    /// Quanto foi aplicado (custo), quando conhecido.
    public var aplicadoCentavos: Int?
    public var lucroCentavos: Int?
    public var quantidade: Double?
    public var valorCotaCentavos: Int?
    public var taxaAnual: Double?
    public var rentabilidade12m: Double?
    public var rentabilidadeMes: Double?
    public var vencimento: Date?
    public var emissor: String?
    public var codigo: String?
    public var manual: Bool = false
    public var ativo: Bool = true
    public var atualizadoEm: Date = Date()

    public init(externalID: String, nome: String, classe: ClasseAtivo, saldoCentavos: Int) {
        self.externalID = externalID
        self.nome = nome
        self.classeRaw = classe.rawValue
        self.saldoCentavos = saldoCentavos
    }

    public var classe: ClasseAtivo {
        get { ClasseAtivo(rawValue: classeRaw) ?? .outros }
        set { classeRaw = newValue.rawValue }
    }

    /// Lucro em reais: usa o informado pela instituição ou calcula (saldo − aplicado).
    public var resultadoCentavos: Int? {
        if let l = lucroCentavos { return l }
        if let a = aplicadoCentavos, a > 0 { return saldoCentavos - a }
        return nil
    }

    public var resultadoPercentual: Double? {
        guard let a = aplicadoCentavos, a > 0, let r = resultadoCentavos else { return nil }
        return Double(r) / Double(a)
    }
}

/// Uma foto por dia do patrimônio, para o gráfico de evolução.
@Model
public final class FotoPatrimonio {
    public var dia: Date = Date()
    public var disponivelCentavos: Int = 0
    public var investidoCentavos: Int = 0
    public var dividasCentavos: Int = 0
    public var liquidoCentavos: Int = 0
    public var demo: Bool = false

    public init(dia: Date, disponivelCentavos: Int, investidoCentavos: Int, dividasCentavos: Int) {
        self.dia = dia
        self.disponivelCentavos = disponivelCentavos
        self.investidoCentavos = investidoCentavos
        self.dividasCentavos = dividasCentavos
        self.liquidoCentavos = disponivelCentavos + investidoCentavos - dividasCentavos
    }
}

public enum EsquemaPrumo {
    public static var tipos: [any PersistentModel.Type] {
        [Conexao.self, Conta.self, Fatura.self, Emprestimo.self,
         Lancamento.self, Orcamento.self, Regra.self, Meta.self, MapaCartao.self,
         Investimento.self, FotoPatrimonio.self, Fixo.self, MarcaFixo.self]
    }

    public static var schema: Schema { Schema(tipos) }

    /// Container do app. Usa iCloud automaticamente quando o app está assinado com CloudKit;
    /// sem isso (build local, testes) fica só no aparelho.
    public static func container(emMemoria: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: emMemoria)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
