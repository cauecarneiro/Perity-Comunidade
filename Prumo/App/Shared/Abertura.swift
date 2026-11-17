import QuartzCore
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// A abertura do app: o "p" do ícone aparece, o ponto de limão cai no lugar e o nome se abre entre os dois
/// ("p●" vira "perity●"). Dura pouco mais de um segundo e some sozinha, entregando a tela para a entrada.
///
/// É feita com Core Animation, e não com animação do SwiftUI, de propósito: as animações são entregues
/// de uma vez ao sistema gráfico, que as desenha sozinho. Assim ela não trava enquanto o app carrega os
/// dados (com 2 mil lançamentos, a primeira conta ocupa o app por alguns décimos de segundo).
struct AberturaView: View {
    /// A abertura começou a sumir: a tela de baixo já pode entrar.
    let aoSair: () -> Void
    /// A abertura sumiu de vez e pode ser tirada da tela.
    let aoSumir: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduzir

    var body: some View {
        CamadasDaAbertura(reduzir: reduzir, aoSair: aoSair, aoSumir: aoSumir)
            .ignoresSafeArea()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Perity")
    }
}

/// Os tempos da abertura, em segundos a partir do início.
private enum TempoDaAbertura {
    static let letra = 0.0
    static let ponto = 0.1
    static let nome = 0.34
    static let saida = 0.98
    static let duracaoSaida = 0.2
}

#if os(iOS)
private struct CamadasDaAbertura: UIViewRepresentable {
    let reduzir: Bool
    let aoSair: () -> Void
    let aoSumir: () -> Void

    func makeUIView(context: Context) -> VistaDaAbertura {
        VistaDaAbertura(reduzir: reduzir, aoSair: aoSair, aoSumir: aoSumir)
    }
    func updateUIView(_ uiView: VistaDaAbertura, context: Context) {}
}

private final class VistaDaAbertura: UIView {
    private let animacao: AnimacaoDaAbertura

    init(reduzir: Bool, aoSair: @escaping () -> Void, aoSumir: @escaping () -> Void) {
        animacao = AnimacaoDaAbertura(reduzir: reduzir, sentidoVertical: 1, aoSair: aoSair, aoSumir: aoSumir)
        super.init(frame: .zero)
        // O fundo preto fica na camada que some, para a tela de baixo aparecer junto com a saída.
        backgroundColor = .clear
        isOpaque = false
        layer.addSublayer(animacao.raiz)
    }
    required init?(coder: NSCoder) { fatalError("não usado") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let escala = traitCollection.displayScale
        animacao.montar(em: bounds, escala: escala > 0 ? escala : 3)
    }
}
#else
private struct CamadasDaAbertura: NSViewRepresentable {
    let reduzir: Bool
    let aoSair: () -> Void
    let aoSumir: () -> Void

    func makeNSView(context: Context) -> VistaDaAbertura {
        VistaDaAbertura(reduzir: reduzir, aoSair: aoSair, aoSumir: aoSumir)
    }
    func updateNSView(_ nsView: VistaDaAbertura, context: Context) {}
}

private final class VistaDaAbertura: NSView {
    private let animacao: AnimacaoDaAbertura

    init(reduzir: Bool, aoSair: @escaping () -> Void, aoSumir: @escaping () -> Void) {
        // No Mac o eixo vertical das camadas cresce para cima: o ponto "cai" no sentido contrário.
        animacao = AnimacaoDaAbertura(reduzir: reduzir, sentidoVertical: -1, aoSair: aoSair, aoSumir: aoSumir)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(animacao.raiz)
    }
    required init?(coder: NSCoder) { fatalError("não usado") }

    override func layout() {
        super.layout()
        animacao.montar(em: bounds, escala: window?.backingScaleFactor ?? 2)
    }
}
#endif

/// Monta as camadas e entrega todas as animações ao sistema gráfico de uma só vez.
@MainActor
private final class AnimacaoDaAbertura {
    let raiz = CALayer()
    private let grupo = CALayer()
    private let letra = CATextLayer()
    private let nome = CATextLayer()
    private let mascaraDoNome = CALayer()
    private let ponto = CALayer()
    private let reduzir: Bool
    private let sentidoVertical: CGFloat
    private let aoSair: () -> Void
    private let aoSumir: () -> Void
    private var montada = false

    private let tamanho: CGFloat = 64

    init(reduzir: Bool, sentidoVertical: CGFloat, aoSair: @escaping () -> Void, aoSumir: @escaping () -> Void) {
        self.reduzir = reduzir
        self.sentidoVertical = sentidoVertical
        self.aoSair = aoSair
        self.aoSumir = aoSumir
    }

    private func texto(_ s: String) -> NSAttributedString {
        #if os(iOS)
        let fonte = UIFont.systemFont(ofSize: tamanho, weight: .semibold)
        let cor = UIColor(red: 0xF4 / 255, green: 0xF4 / 255, blue: 0xF1 / 255, alpha: 1)
        #else
        let fonte = NSFont.systemFont(ofSize: tamanho, weight: .semibold)
        let cor = NSColor(red: 0xF4 / 255, green: 0xF4 / 255, blue: 0xF1 / 255, alpha: 1)
        #endif
        return NSAttributedString(string: s, attributes: [.font: fonte, .foregroundColor: cor, .kern: -tamanho * 0.04])
    }

    func montar(em limites: CGRect, escala: CGFloat) {
        raiz.frame = limites
        raiz.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        guard !montada, limites.width > 0, limites.height > 0 else { return }
        montada = true

        let p = texto("p"), erity = texto("erity")
        let tamP = p.size(), tamErity = erity.size()
        let altura = ceil(max(tamP.height, tamErity.height))
        let diametro = tamanho * 0.2
        let folga = tamanho * 0.06
        let larguraFechada = tamP.width + folga + diametro
        let larguraAberta = tamP.width + tamErity.width + folga + diametro
        let centroX = limites.midX
        let centroY = limites.midY

        // Linha de base: a mesma para as duas palavras; o ponto senta nela.
        #if os(iOS)
        let ascendente = UIFont.systemFont(ofSize: tamanho, weight: .semibold).ascender
        #else
        let ascendente = NSFont.systemFont(ofSize: tamanho, weight: .semibold).ascender
        #endif
        let topoDoTexto = centroY - altura / 2 * sentidoVertical
        let linhaDeBase = topoDoTexto + ascendente * sentidoVertical

        for camada in [letra, nome] {
            camada.contentsScale = escala
            camada.alignmentMode = .left
            camada.isWrapped = false
        }
        letra.string = p
        nome.string = erity
        letra.bounds = CGRect(x: 0, y: 0, width: ceil(tamP.width) + 2, height: altura)
        nome.bounds = CGRect(x: 0, y: 0, width: ceil(tamErity.width) + 2, height: altura)
        letra.anchorPoint = CGPoint(x: 0, y: 0.5)
        nome.anchorPoint = CGPoint(x: 0, y: 0.5)

        // "erity" é revelado por uma máscara que cresce da esquerda para a direita.
        mascaraDoNome.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        mascaraDoNome.anchorPoint = CGPoint(x: 0, y: 0)
        mascaraDoNome.bounds = CGRect(x: 0, y: 0, width: nome.bounds.width, height: altura)
        mascaraDoNome.position = .zero
        nome.mask = mascaraDoNome

        ponto.backgroundColor = CGColor(red: 0xD2 / 255, green: 0xFD / 255, blue: 0x59 / 255, alpha: 1)
        ponto.bounds = CGRect(x: 0, y: 0, width: diametro, height: diametro)
        ponto.cornerRadius = diametro / 2

        grupo.frame = limites
        grupo.addSublayer(letra)
        grupo.addSublayer(nome)
        grupo.addSublayer(ponto)
        raiz.addSublayer(grupo)

        let inicioFechado = centroX - larguraFechada / 2
        let inicioAberto = centroX - larguraAberta / 2
        let yDoTexto = centroY
        let yDoPonto = linhaDeBase - diametro / 2 * sentidoVertical
        let xPontoFechado = inicioFechado + tamP.width + folga + diametro / 2
        let xPontoAberto = inicioAberto + tamP.width + tamErity.width + folga + diametro / 2

        // Valores finais no modelo (o que fica depois das animações).
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        letra.position = CGPoint(x: inicioAberto, y: yDoTexto)
        nome.position = CGPoint(x: inicioAberto + tamP.width, y: yDoTexto)
        ponto.position = CGPoint(x: xPontoAberto, y: yDoPonto)
        CATransaction.commit()

        let base = CACurrentMediaTime()
        let ficaParada = UserDefaults.standard.string(forKey: "prumo-abertura") == "fica"

        if reduzir {
            agendarSaida(base: base, momento: 0.45, ficaParada: ficaParada)
            return
        }

        // 1. O "p" aparece, crescendo um pouco.
        letra.add(mola("opacity", de: 0, para: 1, em: base + TempoDaAbertura.letra, duracao: 0.3, quique: 0), forKey: "aparece")
        letra.add(mola("transform.scale", de: 0.82, para: 1, em: base + TempoDaAbertura.letra, duracao: 0.3, quique: 0.1), forKey: "cresce")
        letra.add(mola("position.x", de: inicioFechado, para: inicioAberto, em: base + TempoDaAbertura.nome, duracao: 0.42, quique: 0), forKey: "abre")

        // 2. O ponto cai no lugar com um toque de mola.
        ponto.add(mola("opacity", de: 0, para: 1, em: base + TempoDaAbertura.ponto, duracao: 0.2, quique: 0), forKey: "aparece")
        ponto.add(mola("transform.scale", de: 0.01, para: 1, em: base + TempoDaAbertura.ponto, duracao: 0.4, quique: 0.42), forKey: "cresce")
        ponto.add(mola("position.y", de: yDoPonto - tamanho * 0.5 * sentidoVertical, para: yDoPonto,
                       em: base + TempoDaAbertura.ponto, duracao: 0.4, quique: 0.42), forKey: "cai")
        ponto.add(mola("position.x", de: xPontoFechado, para: xPontoAberto, em: base + TempoDaAbertura.nome, duracao: 0.42, quique: 0), forKey: "abre")

        // 3. O nome se abre entre o "p" e o ponto.
        nome.add(mola("position.x", de: inicioFechado + tamP.width, para: inicioAberto + tamP.width,
                      em: base + TempoDaAbertura.nome, duracao: 0.42, quique: 0), forKey: "abre")
        nome.add(mola("opacity", de: 0, para: 1, em: base + TempoDaAbertura.nome, duracao: 0.25, quique: 0), forKey: "aparece")
        mascaraDoNome.add(mola("bounds.size.width", de: 0, para: nome.bounds.width, em: base + TempoDaAbertura.nome, duracao: 0.42, quique: 0),
                          forKey: "revela")

        agendarSaida(base: base, momento: TempoDaAbertura.saida, ficaParada: ficaParada)
    }

    /// Some com um leve aumento, e avisa quando a tela de baixo pode entrar e quando a abertura acabou.
    private func agendarSaida(base: CFTimeInterval, momento: Double, ficaParada: Bool) {
        #if DEBUG
        if ficaParada { return }
        #endif
        let quando = base + momento
        // Os avisos saem das próprias animações (quando o sistema gráfico as termina), e não de um relógio
        // à parte: se o app estiver ocupado, a tela de baixo entra junto com o que se vê, nunca antes.
        let some = curva("opacity", de: 1, para: 0, em: quando, duracao: TempoDaAbertura.duracaoSaida)
        some.delegate = AvisoDeFim(aoSumir)
        raiz.add(some, forKey: "some")
        grupo.add(curva("transform.scale", de: 1, para: 1.06, em: quando, duracao: TempoDaAbertura.duracaoSaida), forKey: "afasta")
        // Uma animação curta e invisível marca o instante em que a saída começou a ficar visível.
        let marca = curva("zPosition", de: 0, para: 0, em: quando, duracao: 0.06)
        marca.delegate = AvisoDeFim(aoSair)
        raiz.add(marca, forKey: "saiu")
    }

    private func mola(_ caminho: String, de: Any, para: Any, em inicio: CFTimeInterval, duracao: Double, quique: Double) -> CAAnimation {
        let a = CASpringAnimation(keyPath: caminho)
        // Mola sem quique (quique 0) ou com um pouco (0,4), no tempo pedido.
        let rigidez = pow(2 * .pi / duracao, 2)
        a.mass = 1
        a.stiffness = rigidez
        a.damping = 4 * .pi * (1 - quique) / duracao
        a.initialVelocity = 0
        a.fromValue = de
        a.toValue = para
        a.beginTime = inicio
        a.duration = a.settlingDuration
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        return a
    }

    private func curva(_ caminho: String, de: Any, para: Any, em inicio: CFTimeInterval, duracao: Double) -> CABasicAnimation {
        let a = CABasicAnimation(keyPath: caminho)
        a.fromValue = de
        a.toValue = para
        a.beginTime = inicio
        a.duration = duracao
        a.timingFunction = CAMediaTimingFunction(name: .easeOut)
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        return a
    }
}

/// Chama a ação quando a animação termina. O Core Animation avisa na linha principal.
private final class AvisoDeFim: NSObject, CAAnimationDelegate {
    private let acao: @MainActor () -> Void
    private var avisou = false

    init(_ acao: @escaping @MainActor () -> Void) { self.acao = acao }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard !avisou else { return }
        avisou = true
        MainActor.assumeIsolated { acao() }
    }
}
