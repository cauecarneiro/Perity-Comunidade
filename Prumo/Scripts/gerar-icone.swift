import AppKit
import CoreText

// Desenha o ícone do Perity: um "p" branco e um ponto de limão, sobre preto.
// Uso: swift icone.swift <pasta-de-saida>
let saida = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

func desenhar(lado: Int, mac: Bool) -> Data {
    let n = CGFloat(lado)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: lado, pixelsHigh: lado, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let g = ctx.cgContext
    g.interpolationQuality = .high

    // Fundo: no iPhone ocupa tudo (o sistema recorta); no Mac é o quadrado arredondado com margem.
    let quadro = mac ? CGRect(x: n * 0.0977, y: n * 0.0977, width: n * 0.8046, height: n * 0.8046) : CGRect(x: 0, y: 0, width: n, height: n)
    let raio = mac ? quadro.width * 0.2237 : 0
    let fundo = CGPath(roundedRect: quadro, cornerWidth: raio, cornerHeight: raio, transform: nil)
    g.addPath(fundo)
    g.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    g.fillPath()
    if mac {
        // Fio claro na borda, para o preto não sumir no Dock escuro.
        g.addPath(CGPath(roundedRect: quadro.insetBy(dx: n * 0.002, dy: n * 0.002), cornerWidth: raio, cornerHeight: raio, transform: nil))
        g.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
        g.setLineWidth(max(1, n * 0.004))
        g.strokePath()
    }

    // O "p" (fonte do sistema, peso firme) e o ponto, centrados como um conjunto.
    let u = quadro.width
    let fonte = NSFont.systemFont(ofSize: u * 0.66, weight: .semibold)
    let texto = NSAttributedString(string: "p", attributes: [.font: fonte, .foregroundColor: NSColor(red: 0.957, green: 0.957, blue: 0.945, alpha: 1)])
    let linha = CTLineCreateWithAttributedString(texto)
    let caixa = CTLineGetBoundsWithOptions(linha, .useGlyphPathBounds)
    let ponto = u * 0.118
    let folga = u * 0.045
    let larguraTotal = caixa.width + folga + ponto
    let x0 = quadro.midX - larguraTotal / 2 - caixa.minX
    // Centro vertical do desenho do "p" (com a perna) no centro do quadro.
    let y0 = quadro.midY - caixa.midY
    g.textPosition = CGPoint(x: x0, y: y0)
    CTLineDraw(linha, g)

    // Ponto de limão, apoiado na linha de base.
    let px = x0 + caixa.maxX + folga
    g.setFillColor(CGColor(red: 0.824, green: 0.992, blue: 0.349, alpha: 1))
    g.fillEllipse(in: CGRect(x: px, y: y0, width: ponto, height: ponto))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: saida, withIntermediateDirectories: true)
try desenhar(lado: 1024, mac: false).write(to: saida.appendingPathComponent("icon-1024.png"))
for lado in [16, 32, 64, 128, 256, 512, 1024] {
    try desenhar(lado: lado, mac: true).write(to: saida.appendingPathComponent("mac-\(lado).png"))
}
print("ok")
