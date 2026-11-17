import SwiftUI
import PrumoCore

// MARK: - Superfície

/// Bloco com fundo um degrau acima do preto. Usado com parcimônia: a maior parte das telas é
/// texto direto no preto, separado por espaço e por uma linha fina.
struct Cartao: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Raio.cartao, style: .continuous))
    }
}

extension View {
    func cartaoPrumo(padding: CGFloat = 18) -> some View {
        modifier(Cartao(padding: padding))
    }
}

/// A linha fina que separa blocos.
struct Fio: View {
    var body: some View {
        Rectangle().fill(Tema.linha).frame(height: 1)
    }
}

// MARK: - Número herói

/// O número grande de uma tela: "R$" e centavos menores e apagados, dígitos que rolam quando o valor muda.
struct NumeroHeroi: View {
    @Environment(\.valoresOcultos) private var ocultoNaPagina
    @Environment(\.revelado) private var revelado
    let valor: Int
    var tamanho: CGFloat = 56
    var cor: Color = Tema.texto

    init(centavos: Int, tamanho: CGFloat = 56, cor: Color = Tema.texto) {
        self.valor = centavos
        self.tamanho = tamanho
        self.cor = cor
    }

    /// Enquanto a tela entra, o número parte do zero e conta até o valor.
    private var centavos: Int { revelado ? valor : 0 }

    var body: some View {
        numero
            .animation(Movimento.rapida, value: ocultoNaPagina)
            .animation(Movimento.suave, value: valor)
            .animation(Movimento.contagem, value: revelado)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .privacySensitive()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ocultoNaPagina ? "Valor oculto" : Dinheiro.formatar(valor))
    }

    private var numero: some View {
        let texto = Dinheiro.formatar(abs(centavos))
        let partes = texto.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let inteiro = (partes.first ?? "")
            .replacingOccurrences(of: "R$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cents = partes.count > 1 ? "," + partes[1] : ""
        let oculto = ocultoNaPagina
        let pequeno = tamanho * 0.42
        return HStack(alignment: .firstTextBaseline, spacing: tamanho * 0.06) {
            Text(centavos < 0 && !oculto ? "−R$" : "R$")
                .font(.system(size: pequeno, weight: .medium))
                .foregroundStyle(Tema.secundario)
            Text(oculto ? "••••" : inteiro)
                .font(.numero(oculto ? tamanho * 0.5 : tamanho))
                .tracking(oculto ? tamanho * 0.04 : -tamanho * 0.03)
                .foregroundStyle(cor)
                .contentTransition(.numericText(value: Double(centavos)))
            if !oculto {
                Text(cents)
                    .font(.numero(pequeno, .medium))
                    .foregroundStyle(Tema.secundario)
                    .contentTransition(.numericText(value: Double(centavos)))
            }
        }
    }
}

// MARK: - Toque e botões

/// Resposta ao toque: o bloco apaga um pouco e encolhe quase nada enquanto está pressionado.
struct EstiloToque: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Movimento.rapida, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == EstiloToque {
    static var toque: EstiloToque { EstiloToque() }
}

/// Botão principal (um por tela): limão cheio, texto preto.
struct EstiloPrincipal: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Tema.sobreAcento)
            .background(Tema.acento, in: RoundedRectangle(cornerRadius: Raio.bloco, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Movimento.rapida, value: configuration.isPressed)
    }
}

/// Botão secundário: mesmo tamanho, fundo discreto.
struct EstiloSecundario: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Tema.texto)
            .background(Tema.elevada, in: RoundedRectangle(cornerRadius: Raio.bloco, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Movimento.rapida, value: configuration.isPressed)
    }
}

// MARK: - Seletor

struct OpcaoSeletor<Valor: Hashable>: Identifiable {
    let valor: Valor
    let titulo: String
    var id: Valor { valor }
}

/// Seletor de abas: o destaque desliza até a opção escolhida.
struct Seletor<Valor: Hashable>: View {
    let opcoes: [OpcaoSeletor<Valor>]
    @Binding var selecionado: Valor
    @Namespace private var espaco
    @Environment(\.accessibilityReduceMotion) private var reduzir

    var body: some View {
        HStack(spacing: 2) {
            ForEach(opcoes) { opcao in
                let ativo = opcao.valor == selecionado
                Button {
                    withAnimation(reduzir ? nil : Movimento.rapida) { selecionado = opcao.valor }
                } label: {
                    Text(opcao.titulo)
                        .font(.system(size: 13, weight: ativo ? .semibold : .regular))
                        .foregroundStyle(ativo ? Tema.texto : Tema.secundario)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background {
                            if ativo {
                                RoundedRectangle(cornerRadius: Raio.chip - 2, style: .continuous)
                                    .fill(Tema.elevada)
                                    .matchedGeometryEffect(id: "ativo", in: espaco)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(ativo ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Raio.chip, style: .continuous))
        .sensoryFeedback(.selection, trigger: selecionado)
    }
}

// MARK: - Caixinha de "pago"

/// A caixinha da lista de fixos. Vazia: um aro. Paga: limão cheio com o visto.
struct Caixinha: View {
    let marcada: Bool
    var tamanho: CGFloat = 26
    @Environment(\.accessibilityReduceMotion) private var reduzir

    var body: some View {
        ZStack {
            Circle().strokeBorder(Tema.terciario, lineWidth: 1.5).opacity(marcada ? 0 : 1)
            Circle().fill(Tema.acento).scaleEffect(marcada ? 1 : 0.4).opacity(marcada ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: tamanho * 0.46, weight: .bold))
                .foregroundStyle(Tema.sobreAcento)
                .scaleEffect(marcada ? 1 : 0.3)
                .opacity(marcada ? 1 : 0)
        }
        .frame(width: tamanho, height: tamanho)
        .animation(reduzir ? nil : Movimento.marca, value: marcada)
        .accessibilityHidden(true)
    }
}

/// Um tracinho por item: os pagos em limão. Mostra "12 de 15" sem precisar ler.
struct BarraSegmentos: View {
    let total: Int
    let feitos: Int
    var altura: CGFloat = 6
    @Environment(\.revelado) private var revelado

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                // Ao entrar na tela, os tracinhos acendem um depois do outro.
                Capsule().fill(i < feitos && revelado ? Tema.acento : Tema.trilho)
                    .animation(Movimento.rapida.delay(0.08 + Double(min(i, 24)) * 0.016), value: revelado)
            }
        }
        .frame(height: altura)
        .animation(Movimento.suave, value: feitos)
        .accessibilityHidden(true)
    }
}

// MARK: - Do macro para o micro

/// Espaço de nomes da transição "o bloco cresce e vira a tela de detalhe" (iPhone, iOS 18+).
private struct EspacoZoomChave: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var espacoZoom: Namespace.ID? {
        get { self[EspacoZoomChave.self] }
        set { self[EspacoZoomChave.self] = newValue }
    }
}

private struct OrigemZoom: ViewModifier {
    let id: String
    @Environment(\.espacoZoom) private var espaco

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *), let espaco {
            content.matchedTransitionSource(id: id, in: espaco)
        } else {
            content
        }
    }
}

private struct DestinoZoom: ViewModifier {
    let id: String
    @Environment(\.espacoZoom) private var espaco

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), let espaco {
            content.navigationTransition(.zoom(sourceID: id, in: espaco))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    /// Marca o bloco de onde a tela de detalhe "nasce".
    func origemZoom(_ id: String) -> some View { modifier(OrigemZoom(id: id)) }
    /// Marca a tela de detalhe que cresce a partir do bloco de mesmo `id`.
    func destinoZoom(_ id: String) -> some View { modifier(DestinoZoom(id: id)) }
}
