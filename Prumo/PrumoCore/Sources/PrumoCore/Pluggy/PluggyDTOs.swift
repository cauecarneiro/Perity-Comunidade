import Foundation

// Formatos da API da Pluggy (https://docs.pluggy.ai). Os nomes dos campos espelham o JSON.
// Tudo que não é garantido pela especificação é opcional: o app nunca deve quebrar por campo novo.

/// Lê uma lista pulando os itens que não decodificam (um registro ruim não derruba a conta inteira).
struct ListaTolerante<T: Decodable & Sendable>: Decodable, Sendable {
    let itens: [T]

    private struct Descartado: Decodable {}

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        var saida: [T] = []
        while !c.isAtEnd {
            if let v = try? c.decode(T.self) { saida.append(v) } else { _ = try? c.decode(Descartado.self) }
        }
        itens = saida
    }
}

public struct PluggyPagina<T: Decodable & Sendable>: Decodable, Sendable {
    public let page: Int?
    public let total: Int?
    public let totalPages: Int?
    public let results: [T]

    private enum Chaves: String, CodingKey { case page, total, totalPages, results }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Chaves.self)
        page = try c.decodeIfPresent(Int.self, forKey: .page)
        total = try c.decodeIfPresent(Int.self, forKey: .total)
        totalPages = try c.decodeIfPresent(Int.self, forKey: .totalPages)
        results = try c.decode(ListaTolerante<T>.self, forKey: .results).itens
    }
}

public struct PluggyPaginaCursor<T: Decodable & Sendable>: Decodable, Sendable {
    public let results: [T]
    public let next: String?

    private enum Chaves: String, CodingKey { case results, next }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Chaves.self)
        results = try c.decode(ListaTolerante<T>.self, forKey: .results).itens
        next = try c.decodeIfPresent(String.self, forKey: .next)
    }
}

public struct PluggyConector: Decodable, Sendable {
    public let id: Int?
    public let name: String?
    public let imageUrl: String?
    public let primaryColor: String?
    public let isOpenFinance: Bool?
}

public struct PluggyItem: Decodable, Sendable {
    public let id: String
    public let connector: PluggyConector?
    public let status: String?
    public let executionStatus: String?
    public let lastUpdatedAt: Date?
    public let nextAutoSyncAt: Date?
    public let consentExpiresAt: Date?
}

public struct PluggyDadosBancarios: Decodable, Sendable {
    public let transferNumber: String?
    public let closingBalance: Double?
    public let automaticallyInvestedBalance: Double?
    public let overdraftContractedLimit: Double?
    public let overdraftUsedLimit: Double?
}

public struct PluggyDadosCartao: Decodable, Sendable {
    public let level: String?
    public let brand: String?
    public let balanceCloseDate: Date?
    public let balanceDueDate: Date?
    public let availableCreditLimit: Double?
    public let minimumPayment: Double?
    public let creditLimit: Double?
    public let status: String?
}

public struct PluggyConta: Decodable, Sendable {
    public let id: String
    public let type: String?        // BANK | CREDIT
    public let subtype: String?     // CHECKING_ACCOUNT | SAVINGS_ACCOUNT | CREDIT_CARD
    public let number: String?
    public let name: String?
    public let marketingName: String?
    public let balance: Double?
    public let itemId: String?
    public let taxNumber: String?
    public let owner: String?
    public let currencyCode: String?
    public let bankData: PluggyDadosBancarios?
    public let creditData: PluggyDadosCartao?
}

public struct PluggyDocumento: Decodable, Sendable {
    public let type: String?
    public let value: String?
}

public struct PluggyParte: Decodable, Sendable {
    public let name: String?
    public let documentNumber: PluggyDocumento?
}

public struct PluggyDadosPagamento: Decodable, Sendable {
    public let payer: PluggyParte?
    public let receiver: PluggyParte?
    public let paymentMethod: String?
    public let reason: String?
}

public struct PluggyDadosCartaoTransacao: Decodable, Sendable {
    public let installmentNumber: Int?
    public let totalInstallments: Int?
    public let totalAmount: Double?
    public let purchaseDate: Date?
    public let cardNumber: String?
    public let billId: String?
}

public struct PluggyEstabelecimento: Decodable, Sendable {
    public let name: String?
    public let businessName: String?
    public let cnpj: String?
    public let category: String?
}

public struct PluggyTransacao: Decodable, Sendable {
    public let id: String
    public let description: String?
    public let descriptionRaw: String?
    public let currencyCode: String?
    public let amount: Double
    public let amountInAccountCurrency: Double?
    public let date: Date
    public let type: String?        // DEBIT | CREDIT
    public let status: String?      // POSTED | PENDING
    public let category: String?
    public let categoryId: String?
    public let paymentData: PluggyDadosPagamento?
    public let creditCardMetadata: PluggyDadosCartaoTransacao?
    public let merchant: PluggyEstabelecimento?
    public let accountId: String?
}

public struct PluggyPagamentoFatura: Decodable, Sendable {
    public let amount: Double?
    public let paymentDate: Date?
}

public struct PluggyFatura: Decodable, Sendable {
    public let id: String
    public let dueDate: Date
    public let billClosingDate: Date?
    public let totalAmount: Double?
    public let minimumPaymentAmount: Double?
    public let payments: [PluggyPagamentoFatura]?
}

public struct PluggyInvestimento: Decodable, Sendable {
    public let id: String
    public let itemId: String?
    public let type: String?
    public let subtype: String?
    public let name: String?
    public let balance: Double?
    public let amount: Double?
    public let amountProfit: Double?
    public let amountOriginal: Double?
    public let value: Double?
    public let quantity: Double?
    public let annualRate: Double?
    public let lastMonthRate: Double?
    public let lastTwelveMonthsRate: Double?
    public let code: String?
    public let dueDate: Date?
    public let issuer: String?
    public let rate: Double?
    public let fixedAnnualRate: Double?
}

public struct PluggyEmprestimo: Decodable, Sendable {
    public let id: String
    public let productName: String?
    public let contractAmount: Double?
    public let dueDate: Date?
    public let firstInstallmentDueDate: Date?
    public let installmentPeriodicity: String?
    public let CET: Double?
    public let installments: PluggyParcelasEmprestimo?
    public let payments: PluggyPagamentosEmprestimo?
}

public struct PluggyParcelasEmprestimo: Decodable, Sendable {
    public let totalNumberOfInstallments: Int?
    public let paidInstallments: Int?
    public let dueInstallments: Int?
    public let contractRemainingNumber: Int?
}

public struct PluggyPagamentosEmprestimo: Decodable, Sendable {
    public let contractOutstandingBalance: Double?
}

public struct PluggySaldo: Decodable, Sendable {
    public let balance: Double
    public let blockedBalance: Double?
    public let updateDateTime: Date?
}

// MARK: - Decodificação de datas

public enum PluggyJSON {
    private static let comFracao: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let semFracao: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let apenasDia: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    public static func data(de texto: String) -> Date? {
        comFracao.date(from: texto) ?? semFracao.date(from: texto) ?? apenasDia.date(from: texto)
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            guard let data = PluggyJSON.data(de: s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Data inválida: \(s)")
            }
            return data
        }
        return d
    }
}
