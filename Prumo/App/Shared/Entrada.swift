import SwiftUI
import PrumoCore

// A entrada das telas: toda vez que uma tela aparece (trocar de aba, abrir um detalhe), os blocos
// sobem, os números contam, as barras enchem e os gráficos se desenham. É rápida e não espera nada:
// o primeiro bloco começa no mesmo instante em que a tela aparece.

private struct ReveladoChave: EnvironmentKey {
    // Fora de uma tela animada (folhas, formulários, widgets), tudo aparece pronto.
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Falso só no instante em que a tela entra; ao virar verdadeiro, as peças animam até o lugar.
    var revelado: Bool {
        get { self[ReveladoChave.self] }
        set { self[ReveladoChave.self] = newValue }
    }
}

private struct ValoresOcultosChave: EnvironmentKey {
    // Fora de uma página (folhas, formulários, widgets), os valores aparecem.
    static let defaultValue = false
}

extension EnvironmentValues {
    /// O olho desta página está fechado. Cada página (Início, Investimentos, Fixos) tem o seu;
    /// os detalhes do Início herdam o do Início. `Valor`, `TextoPrivado` e `NumeroHeroi` obedecem.
    var valoresOcultos: Bool {
        get { self[ValoresOcultosChave.self] }
        set { self[ValoresOcultosChave.self] = newValue }
    }
}

/// Controla a entrada de uma tela. Em abas (`secao`), repete a cada vez que a aba é escolhida;
/// em telas de detalhe, a cada vez que a tela é aberta. Voltar de um detalhe não repete.
/// Na raiz de uma aba, também entrega o olho daquela página (`valoresOcultos`).
struct EntradaDeTela: ViewModifier {
    var secao: Secao?
    @Environment(EstadoApp.self) private var estado
    @Environment(\.accessibilityReduceMotion) private var reduzir
    @Environment(\.valoresOcultos) private var ocultosHerdados
    @State private var revelado = false

    private var ativa: Bool { !estado.abrindo && (secao == nil || estado.secao == secao) }

    func body(content: Content) -> some View {
        content
            .environment(\.valoresOcultos, secao.map(estado.oculta) ?? ocultosHerdados)
            .environment(\.revelado, revelado || reduzir)
            .onAppear { if ativa, !revelado { revelar() } }
            // O contador sobe a cada troca de aba, então a volta para a mesma aba nunca passa despercebida.
            .onChange(of: estado.selecoes) { _, _ in
                // A aba que sai fica como está (some inteira, sem piscar); a que entra recomeça a entrada.
                if secao != nil, ativa { revelar() }
            }
            .onChange(of: estado.abrindo) { _, _ in if ativa { revelar() } }
    }

    private func esconder() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { revelado = false }
    }

    private func revelar() {
        guard !reduzir else { revelado = true; return }
        // Primeiro o estado inicial, sem animar; no instante seguinte, a entrada.
        esconder()
        DispatchQueue.main.async { revelado = true }
    }
}

private struct Entrada: ViewModifier {
    let ordem: Int
    @Environment(\.revelado) private var revelado

    func body(content: Content) -> some View {
        // O bloco fica visível quase na hora (para não haver tela vazia) e termina de subir logo depois.
        content
            .opacity(revelado ? 1 : 0)
            .animation(Movimento.aparecer(ordem), value: revelado)
            .offset(y: revelado ? 0 : 12)
            .animation(Movimento.entrada(ordem), value: revelado)
    }
}

/// O gráfico "se desenha": uma máscara abre da esquerda para a direita (linhas) ou de baixo para cima (barras).
private struct DesenhoDeGrafico: ViewModifier {
    let deBaixo: Bool
    @Environment(\.revelado) private var revelado

    func body(content: Content) -> some View {
        content
            .mask {
                Rectangle()
                    .padding(-10)
                    .scaleEffect(x: deBaixo || revelado ? 1 : 0, y: !deBaixo || revelado ? 1 : 0,
                                 anchor: deBaixo ? .bottom : .leading)
            }
            .animation(Movimento.desenho, value: revelado)
    }
}

extension View {
    /// Liga a animação de entrada desta tela. `secao` quando a tela é a raiz de uma aba.
    func entradaDeTela(_ secao: Secao? = nil) -> some View {
        modifier(EntradaDeTela(secao: secao))
    }

    /// O bloco sobe e aparece quando a tela entra. `ordem` atrasa um nada cada bloco (0, 1, 2…).
    func entrada(_ ordem: Int = 0) -> some View {
        modifier(Entrada(ordem: ordem))
    }

    /// O gráfico se desenha quando a tela entra.
    func desenhaAoEntrar(deBaixo: Bool = false) -> some View {
        modifier(DesenhoDeGrafico(deBaixo: deBaixo))
    }
}

extension View {
    /// Fotos das telas (só em desenvolvimento): `-prumo-rolar 0.5` abre a tela já rolada até a metade; `1` até o fim.
    @ViewBuilder func rolagemDeTeste() -> some View {
        #if DEBUG
        let y = UserDefaults.standard.double(forKey: "prumo-rolar")
        if y > 0 {
            self.defaultScrollAnchor(UnitPoint(x: 0.5, y: min(y, 1)))
        } else {
            self
        }
        #else
        self
        #endif
    }
}
