import Foundation
import SwiftData

public enum OrigemLancamento: String, CaseIterable, Sendable {
    case openFinance, carteira, manual, importado, demo

    public var nome: String {
        switch self {
        case .openFinance: "Banco"
        case .carteira: "Apple Pay"
        case .manual: "Manual"
        case .importado: "Importado"
        case .demo: "Demonstração"
        }
    }

    /// Lançamentos que chegam na hora e depois são confirmados pelo banco.
    public var ehProvisoria: Bool { self == .carteira || self == .manual }
}

public enum StatusLancamento: String, Sendable {
    case efetivado, pendente
}

@Model
public final class Lancamento {
    public var externalID: String = ""
    public var contaID: String = ""
    /// Dia do lançamento (meio-dia local do dia civil).
    public var data: Date = Date()
    public var descricao: String = ""
    public var descricaoOriginal: String?
    public var estabelecimento: String?
    /// Com sinal: negativo = saiu dinheiro, positivo = entrou.
    public var valorCentavos: Int = 0
    public var moeda: String = "BRL"
    public var categoriaChave: String = "outros"
    public var categoriaManual: Bool = false
    public var statusRaw: String = StatusLancamento.efetivado.rawValue
    public var origemRaw: String = OrigemLancamento.manual.rawValue
    public var parcelaAtual: Int?
    public var totalParcelas: Int?
    public var faturaID: String?
    /// Transferência entre contas suas, pagamento de fatura ou aporte: não é gasto nem renda.
    public var interno: Bool = false
    /// Você mesmo marcou (ou desmarcou) como interno: a sincronização não mexe mais nisso.
    public var internoManual: Bool = false
    public var ignorado: Bool = false
    public var notas: String?
    /// Quando um lançamento provisório (Apple Pay/manual) é confirmado pelo banco, aponta para o oficial.
    public var conciliadoComID: String?
    public var cartaoCarteira: String?
    public var criadoEm: Date = Date()
    public var atualizadoEm: Date = Date()

    public init(externalID: String = UUID().uuidString,
                contaID: String = "",
                data: Date = Date(),
                descricao: String,
                valorCentavos: Int,
                origem: OrigemLancamento = .manual) {
        self.externalID = externalID
        self.contaID = contaID
        self.data = data
        self.descricao = descricao
        self.valorCentavos = valorCentavos
        self.origemRaw = origem.rawValue
    }

    public var origem: OrigemLancamento {
        get { OrigemLancamento(rawValue: origemRaw) ?? .manual }
        set { origemRaw = newValue.rawValue }
    }

    public var status: StatusLancamento {
        get { StatusLancamento(rawValue: statusRaw) ?? .efetivado }
        set { statusRaw = newValue.rawValue }
    }

    public var ehSaida: Bool { valorCentavos < 0 }
    // valorAbsoluto, contaParaRelatorios, categoria e titulo vêm de `LancamentoAnalisavel` (LancamentoLeve.swift).
}

@Model
public final class Orcamento {
    public var categoriaChave: String = ""
    public var valorCentavos: Int = 0
    public var atualizadoEm: Date = Date()
    public var demo: Bool = false

    public init(categoriaChave: String, valorCentavos: Int) {
        self.categoriaChave = categoriaChave
        self.valorCentavos = valorCentavos
    }
}

/// "Sempre que a descrição tiver X, a categoria é Y" — aprendida quando você corrige uma categoria.
@Model
public final class Regra {
    public var padrao: String = ""
    public var categoriaChave: String = "outros"
    public var marcarInterno: Bool = false
    public var criadaEm: Date = Date()

    public init(padrao: String, categoriaChave: String, marcarInterno: Bool = false) {
        self.padrao = padrao
        self.categoriaChave = categoriaChave
        self.marcarInterno = marcarInterno
    }
}

@Model
public final class Meta {
    public var nome: String = ""
    public var alvoCentavos: Int = 0
    public var guardadoCentavos: Int = 0
    public var prazo: Date?
    public var icone: String = "flag.fill"
    public var corHex: String = "0C47F9"
    public var criadaEm: Date = Date()
    public var demo: Bool = false

    public init(nome: String, alvoCentavos: Int, guardadoCentavos: Int = 0, prazo: Date? = nil) {
        self.nome = nome
        self.alvoCentavos = alvoCentavos
        self.guardadoCentavos = guardadoCentavos
        self.prazo = prazo
    }

    public var progresso: Double {
        guard alvoCentavos > 0 else { return 0 }
        return min(1, max(0, Double(guardadoCentavos) / Double(alvoCentavos)))
    }
}

/// Liga o nome do cartão na Carteira da Apple ("Nubank Mastercard •• 1234") a uma conta do app.
@Model
public final class MapaCartao {
    public var nomeCarteira: String = ""
    public var contaID: String = ""

    public init(nomeCarteira: String, contaID: String) {
        self.nomeCarteira = nomeCarteira
        self.contaID = contaID
    }
}
