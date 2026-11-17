import SwiftUI
import PrumoCore

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

/// Fichas visuais do Perity ("Tinta e Marca-texto"). Ver docs/DESIGN.md.
/// O app é sempre escuro: preto, branco em três intensidades e uma cor de destaque (limão).
enum Tema {
    /// A cor de destaque: marca o que está pago, o que é ação e o que rendeu.
    static let acento = Color(hex: "D2FD59")
    /// Texto e ícone em cima do limão.
    static let sobreAcento = Color.black

    static let fundo = Color.black
    /// Folhas, cartões e campos: um degrau acima do preto.
    static let superficie = Color(hex: "0F0F10")
    /// Opção escolhida, chips ligados: dois degraus acima.
    static let elevada = Color(hex: "1C1C1E")

    static let texto = Color(hex: "F4F4F1")
    static let secundario = Color.white.opacity(0.56)
    static let terciario = Color.white.opacity(0.34)
    static let linha = Color.white.opacity(0.10)
    /// Trilho de barras: quase invisível.
    static let trilho = Color.white.opacity(0.09)

    // Só quando significam algo.
    static let vermelho = Color(hex: "FF6B5E")
    static let ambar = Color(hex: "FFB84D")

    static func cor(_ severidade: SeveridadeInsight) -> Color {
        switch severidade {
        case .alerta: vermelho
        case .atencao: ambar
        case .info: secundario
        case .positivo: acento
        }
    }
}

/// Raios de canto. Sempre `.continuous`.
enum Raio {
    static let cartao: CGFloat = 20
    static let bloco: CGFloat = 14
    static let chip: CGFloat = 10
}

/// Movimento do app: curto, sem quique e sem espera. Ver "Animações" em docs/DESIGN.md.
enum Movimento {
    static let suave = Animation.smooth(duration: 0.3)
    static let rapida = Animation.snappy(duration: 0.18)
    /// Entrada de um bloco quando a tela aparece. O primeiro não espera; os seguintes saem 22 ms depois um do outro.
    static func entrada(_ ordem: Int = 0) -> Animation {
        .spring(duration: 0.38, bounce: 0).delay(Double(min(max(ordem, 0), 9)) * 0.022)
    }
    /// O bloco aparece (opacidade) mais rápido do que sobe: em um décimo de segundo já dá para ler.
    static func aparecer(_ ordem: Int = 0) -> Animation {
        .easeOut(duration: 0.14).delay(Double(min(max(ordem, 0), 9)) * 0.022)
    }
    /// Número que conta do zero até o valor e barra que enche.
    static let contagem = Animation.spring(duration: 0.5, bounce: 0)
    /// Gráfico que se desenha.
    static let desenho = Animation.easeOut(duration: 0.55)
    /// Para a caixinha de "pago": um toque de mola, porque é o gesto que dá gosto de fazer.
    static let marca = Animation.spring(duration: 0.35, bounce: 0.25)
}

extension Font {
    /// Número em reais: dígitos de largura fixa, peso firme.
    static func numero(_ tamanho: CGFloat, _ peso: Font.Weight = .semibold) -> Font {
        .system(size: tamanho, weight: peso).monospacedDigit()
    }
}

extension View {
    /// Rótulo de seção: pequeno, em caixa-alta, na fonte de máquina. É a "etiqueta" de cada número.
    func rotulo() -> some View {
        self.font(.system(size: 11, weight: .medium, design: .monospaced))
            .textCase(.uppercase)
            .tracking(0.9)
            .foregroundStyle(Tema.secundario)
    }

    /// Texto de apoio abaixo de um número.
    func apoio() -> some View {
        self.font(.footnote).foregroundStyle(Tema.secundario)
    }

    func numeroGrande() -> some View {
        self.font(.numero(40)).tracking(-0.8).lineLimit(1).minimumScaleFactor(0.5)
    }
}

extension Int {
    /// Centavos → reais (para eixos de gráfico).
    var emReais: Double { Double(self) / 100 }
}

extension Date {
    var diaMesCurto: String { formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "pt_BR"))) }
    var mesAno: String { Texto.primeiraMaiuscula(formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "pt_BR")))) }
    var mesCurto: String { Texto.primeiraMaiuscula(formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "pt_BR")))) }
}

func textoRelativo(_ data: Date, agora: Date = Date()) -> String {
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "pt_BR")
    f.unitsStyle = .full
    return f.localizedString(for: data, relativeTo: agora)
}

func tituloDoDia(_ data: Date, hoje: Date = Date()) -> String {
    let cal = Datas.calendario
    if cal.isDate(data, inSameDayAs: hoje) { return "Hoje" }
    if let ontem = cal.date(byAdding: .day, value: -1, to: hoje), cal.isDate(data, inSameDayAs: ontem) { return "Ontem" }
    return Texto.primeiraMaiuscula(data.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "pt_BR"))))
}
