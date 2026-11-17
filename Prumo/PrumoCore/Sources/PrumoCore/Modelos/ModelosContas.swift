import Foundation
import SwiftData

// Regras de modelagem (compatíveis com CloudKit):
// - toda propriedade tem valor padrão ou é opcional;
// - sem @Attribute(.unique) e sem relacionamentos: as ligações são por texto (externalID/itemID);
// - duplicatas por sincronização simultânea são removidas por `Higiene.deduplicar`.

public enum TipoConta: String, CaseIterable, Sendable {
    case corrente, poupanca, cartao, dinheiro, investimento, outro

    public var nome: String {
        switch self {
        case .corrente: "Conta corrente"
        case .poupanca: "Poupança"
        case .cartao: "Cartão de crédito"
        case .dinheiro: "Dinheiro"
        case .investimento: "Conta de investimento"
        case .outro: "Outra conta"
        }
    }

    public var icone: String {
        switch self {
        case .corrente: "building.columns.fill"
        case .poupanca: "banknote.fill"
        case .cartao: "creditcard.fill"
        case .dinheiro: "wallet.pass.fill"
        case .investimento: "chart.line.uptrend.xyaxis"
        case .outro: "square.grid.2x2.fill"
        }
    }

    public var ehCartao: Bool { self == .cartao }
}

/// Uma conexão com uma instituição (um "item" da Pluggy).
@Model
public final class Conexao {
    public var itemID: String = ""
    public var nome: String = ""
    public var logoURL: String?
    public var corHex: String?
    public var status: String = "CREATED"
    public var ultimaAtualizacao: Date?
    public var proximaAtualizacao: Date?
    public var consentimentoExpiraEm: Date?
    public var ordem: Int = 0
    public var ativa: Bool = true
    public var demo: Bool = false
    public var criadaEm: Date = Date()

    public init(itemID: String, nome: String, demo: Bool = false) {
        self.itemID = itemID
        self.nome = nome
        self.demo = demo
    }

    /// Situações em que o banco precisa que você reconecte ou aprove algo.
    public var precisaAtencao: Bool {
        ["LOGIN_ERROR", "OUTDATED", "WAITING_USER_INPUT", "ERROR"].contains(status)
    }
}

@Model
public final class Conta {
    public var externalID: String = ""
    public var conexaoItemID: String = ""
    public var instituicao: String = ""
    public var logoURL: String?
    public var corHex: String?
    public var nome: String = ""
    public var apelido: String?
    public var tipoRaw: String = TipoConta.corrente.rawValue
    /// Conta/poupança: saldo disponível. Cartão: valor atual da fatura em aberto (dívida).
    public var saldoCentavos: Int = 0
    public var moeda: String = "BRL"
    public var limiteCentavos: Int?
    public var disponivelCentavos: Int?
    public var fechamentoFatura: Date?
    public var vencimentoFatura: Date?
    public var minimoFaturaCentavos: Int?
    public var bandeira: String?
    public var final4: String?
    public var manual: Bool = false
    public var arquivada: Bool = false
    public var contaNoPatrimonio: Bool = true
    public var ordem: Int = 0
    public var atualizadaEm: Date = Date()

    public init(externalID: String, nome: String, tipo: TipoConta, instituicao: String = "") {
        self.externalID = externalID
        self.nome = nome
        self.tipoRaw = tipo.rawValue
        self.instituicao = instituicao
    }

    public var tipo: TipoConta {
        get { TipoConta(rawValue: tipoRaw) ?? .outro }
        set { tipoRaw = newValue.rawValue }
    }

    public var nomeExibicao: String {
        if let a = apelido, !a.isEmpty { return a }
        return nome
    }

    /// Quanto do limite já foi usado (0...1). Nil se não houver limite conhecido.
    public var usoDoLimite: Double? {
        guard tipo.ehCartao, let limite = limiteCentavos, limite > 0 else { return nil }
        if let disp = disponivelCentavos { return min(1, max(0, Double(limite - disp) / Double(limite))) }
        return min(1, max(0, Double(max(saldoCentavos, 0)) / Double(limite)))
    }
}

@Model
public final class Fatura {
    public var externalID: String = ""
    public var contaID: String = ""
    public var vencimento: Date = Date()
    public var fechamento: Date?
    public var totalCentavos: Int = 0
    public var minimoCentavos: Int?
    public var pagaCentavos: Int = 0
    public var atualizadaEm: Date = Date()

    public init(externalID: String, contaID: String, vencimento: Date, totalCentavos: Int) {
        self.externalID = externalID
        self.contaID = contaID
        self.vencimento = vencimento
        self.totalCentavos = totalCentavos
    }

    public var paga: Bool { totalCentavos > 0 && pagaCentavos >= totalCentavos }
    public var emAberto: Int { max(0, totalCentavos - pagaCentavos) }
}

@Model
public final class Emprestimo {
    public var externalID: String = ""
    public var conexaoItemID: String = ""
    public var instituicao: String = ""
    public var nome: String = ""
    public var contratadoCentavos: Int = 0
    public var saldoDevedorCentavos: Int?
    public var parcelaCentavos: Int?
    public var parcelasRestantes: Int?
    public var proximoVencimento: Date?
    public var vencimentoFinal: Date?
    public var custoEfetivoTotal: Double?
    public var atualizadoEm: Date = Date()

    public init(externalID: String, nome: String, contratadoCentavos: Int) {
        self.externalID = externalID
        self.nome = nome
        self.contratadoCentavos = contratadoCentavos
    }
}
