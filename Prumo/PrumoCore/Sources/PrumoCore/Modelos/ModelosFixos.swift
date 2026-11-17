import Foundation
import SwiftData

/// Como um gasto fixo costuma ser pago.
public enum FormaPagamento: String, CaseIterable, Sendable {
    case cartao, boleto, pix, debito, outro

    public var nome: String {
        switch self {
        case .cartao: "Cartão"
        case .boleto: "Boleto"
        case .pix: "Pix"
        case .debito: "Débito"
        case .outro: "Outro"
        }
    }
}

/// Um gasto fixo do mês (aluguel, academia, assinatura, mercado…): a linha da lista com caixinha de "pago".
@Model
public final class Fixo {
    public var uid: String = ""
    public var nome: String = ""
    public var categoriaChave: String = "outros"
    /// Valor combinado. Quando o extrato mostra outro valor, a tela usa o do extrato.
    public var valorCentavos: Int = 0
    public var formaRaw: String = FormaPagamento.cartao.rawValue
    /// Como aparece no extrato. Aceita alternativas separadas por vírgula ("claude, anthropic"). Vazio = usa o nome.
    public var padrao: String = ""
    /// Vários gastos no mês que somam (mercado, gasolina), em vez de um pagamento só.
    public var acumula: Bool = false
    public var ativo: Bool = true
    public var ordem: Int = 0
    public var demo: Bool = false
    public var criadoEm: Date = Date()
    /// Conta ou cartão de onde costuma sair (externalID da `Conta`).
    public var contaID: String?
    /// Dia do mês em que costuma ser cobrado.
    public var diaTipico: Int?
    /// Criado pela varredura do extrato, não por você.
    public var automatico: Bool = false

    public init(nome: String, valorCentavos: Int, forma: FormaPagamento = .cartao, categoriaChave: String = "outros",
                padrao: String = "", acumula: Bool = false, contaID: String? = nil, diaTipico: Int? = nil,
                automatico: Bool = false) {
        self.uid = UUID().uuidString
        self.nome = nome
        self.valorCentavos = valorCentavos
        self.formaRaw = forma.rawValue
        self.categoriaChave = categoriaChave
        self.padrao = padrao
        self.acumula = acumula
        self.contaID = contaID
        self.diaTipico = diaTipico
        self.automatico = automatico
    }

    public var forma: FormaPagamento {
        get { FormaPagamento(rawValue: formaRaw) ?? .outro }
        set { formaRaw = newValue.rawValue }
    }

    public var categoria: CategoriaInfo { Categorias.info(categoriaChave) }
}

/// Marcação feita à mão em um mês: "paguei" (ou "não paguei", para desfazer uma detecção errada).
/// Sem marcação, vale o que o extrato mostrar.
@Model
public final class MarcaFixo {
    public var fixoUID: String = ""
    /// "2026-10"
    public var mes: String = ""
    public var pago: Bool = true
    public var marcadoEm: Date = Date()
    public var demo: Bool = false

    public init(fixoUID: String, mes: String, pago: Bool) {
        self.fixoUID = fixoUID
        self.mes = mes
        self.pago = pago
    }
}
