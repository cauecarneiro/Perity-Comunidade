import SwiftUI
import PrumoCore

/// Valor em reais que respeita o modo "ocultar valores".
/// Sem `colorido`, herda a cor do contexto. Com `colorido`, o que entrou fica em limão.
struct Valor: View {
    @Environment(\.valoresOcultos) private var oculto
    let centavos: Int
    var comSinal = false
    var compacto = false
    var colorido = false

    var body: some View {
        Group {
            if colorido, centavos > 0 {
                base.foregroundStyle(Tema.acento)
            } else {
                base
            }
        }
        .privacySensitive()
    }

    private var base: some View {
        Text(texto)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(centavos)))
            .animation(Movimento.rapida, value: centavos)
            .animation(Movimento.rapida, value: oculto)
    }

    private var texto: String {
        if oculto { return "R$ ••••" }
        let base = compacto ? Dinheiro.formatarCompacto(abs(centavos)) : Dinheiro.formatar(abs(centavos))
        if centavos < 0 { return "−" + base }
        return comSinal && centavos > 0 ? "+" + base : base
    }
}

/// Texto que pode conter valores em reais: respeita o modo "ocultar valores".
struct TextoPrivado: View {
    @Environment(\.valoresOcultos) private var oculto
    let texto: String
    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(oculto ? Texto.ocultarDinheiro(texto) : texto).privacySensitive()
    }
}

/// Etiqueta pequena na fonte de máquina ("AO VIVO", "2/5", "PIX").
struct Selo: View {
    let texto: String
    var cor: Color = Tema.secundario

    var body: some View {
        Text(texto)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(cor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(cor.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct BarraProgresso: View {
    let valor: Double
    var cor: Color = Tema.acento
    var altura: CGFloat = 6
    @Environment(\.revelado) private var revelado

    var body: some View {
        // Ao entrar na tela, a barra enche do zero até o valor.
        let fracao = revelado ? min(1, max(0, valor)) : 0
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.trilho)
                Capsule().fill(cor)
                    .frame(width: max(altura, g.size.width * fracao))
                    .opacity(revelado ? 1 : 0)
            }
        }
        .frame(height: altura)
        .animation(Movimento.suave, value: valor)
        .animation(Movimento.contagem, value: revelado)
        .accessibilityHidden(true)
    }
}

/// Cabeçalho de seção: a etiqueta à esquerda e, se houver, um atalho à direita.
struct CabecalhoSecao<Atalho: View>: View {
    let titulo: String
    @ViewBuilder var atalho: () -> Atalho

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo).rotulo()
            Spacer(minLength: 8)
            atalho()
        }
    }
}

extension CabecalhoSecao where Atalho == EmptyView {
    init(titulo: String) {
        self.titulo = titulo
        self.atalho = { EmptyView() }
    }
}

/// "Ver todos ›": o atalho discreto, na cor de destaque.
struct RotuloLink: View {
    let texto: String

    var body: some View {
        HStack(spacing: 3) {
            Text(texto)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Tema.acento)
    }
}

/// A setinha de "toque para ver o detalhe".
struct Seta: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Tema.terciario)
            .accessibilityHidden(true)
    }
}

struct EstadoVazio: View {
    let titulo: String
    let texto: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.headline)
            Text(texto).font(.subheadline).foregroundStyle(Tema.secundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

/// Uma linha de lançamento: nome, uma linha de contexto e o valor.
struct LinhaLancamento: View {
    let lancamento: Lancamento
    var nomeConta: String?
    var mostrarData = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(lancamento.titulo).font(.body).lineLimit(1)
                    if lancamento.origem == .carteira { Selo(texto: "Ao vivo", cor: Tema.acento) }
                    if lancamento.status == .pendente { Selo(texto: "Pendente", cor: Tema.ambar) }
                    if let p = lancamento.parcelaAtual, let t = lancamento.totalParcelas, t > 1 { Selo(texto: "\(p)/\(t)") }
                }
                Text(subtitulo).font(.caption).foregroundStyle(Tema.secundario).lineLimit(1)
            }
            Spacer(minLength: 8)
            Valor(centavos: lancamento.valorCentavos, colorido: true)
                .font(.numero(16, .medium))
                .opacity(lancamento.interno ? 0.5 : 1)
        }
        .contentShape(Rectangle())
    }

    private var subtitulo: String {
        var partes: [String] = []
        if mostrarData { partes.append(lancamento.data.diaMesCurto) }
        partes.append(lancamento.interno ? "Entre contas" : lancamento.categoria.nome)
        if let c = nomeConta, !c.isEmpty { partes.append(c) }
        return partes.joined(separator: " · ")
    }
}

/// Uma linha simples de lista: título, apoio e valor à direita.
struct LinhaValor: View {
    let titulo: String
    var apoio: String?
    let centavos: Int
    var seta = false
    var corApoio: Color = Tema.secundario

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.body).lineLimit(1)
                if let apoio { Text(apoio).font(.caption).foregroundStyle(corApoio).lineLimit(1) }
            }
            Spacer(minLength: 8)
            Valor(centavos: centavos).font(.numero(16, .medium))
            if seta { Seta() }
        }
        .contentShape(Rectangle())
    }
}

/// Mostra o estado da atualização com os bancos, em uma frase curta.
struct IndicadorAtualizacao: View {
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        HStack(spacing: 6) {
            switch estado.atualizacao {
            case .atualizando:
                ProgressView().controlSize(.mini)
                Text("Atualizando…")
            case .concluida(let texto, let quando, let comErro):
                Text("\(texto) · \(textoRelativo(quando))").foregroundStyle(comErro ? Tema.ambar : Tema.terciario)
            case .ociosa:
                if estado.modoDemo {
                    Text("Dados de exemplo")
                } else if let u = estado.ultimaAtualizacao {
                    Text("Atualizado \(textoRelativo(u))")
                } else {
                    Text("Sem conexão com bancos")
                }
            }
        }
        .font(.caption)
        .lineLimit(1)
        .foregroundStyle(Tema.terciario)
    }
}
