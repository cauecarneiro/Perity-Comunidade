#if DEBUG
import AppKit
import SwiftUI
import PrumoCore

/// Uso (só em build de desenvolvimento):
///   Prumo.app/Contents/MacOS/Prumo -prumo-captura /pasta/de/saida
/// Abre o app com dados de exemplo em memória, tira uma foto de cada página e fecha.
/// Serve para conferir o visual sem ninguém na frente do Mac. Nada é gravado nos seus dados.
@MainActor
enum CapturaDeTelas {
    static func executarSeSolicitado(_ estado: EstadoApp) async {
        guard let pasta = UserDefaults.standard.string(forKey: "prumo-captura") else { return }
        let destino = URL(fileURLWithPath: pasta, isDirectory: true)
        try? FileManager.default.createDirectory(at: destino, withIntermediateDirectories: true)

        // Guarda as preferências para devolver como estavam. `terminate` sai do processo sem rodar `defer`,
        // então a restauração é feita à mão antes de fechar.
        let anterior = (modo: Preferencias.modoDemo, ocultas: Set(Secao.allCases.filter { estado.oculta($0) }))
        let janelaPrincipal = NSApplication.shared.windows.first(where: { $0.isVisible && !($0 is NSPanel) })
        let quadroOriginal = janelaPrincipal?.frame
        func restaurar() {
            // O macOS lembra o tamanho da janela: devolve o original para o app de verdade não abrir com 2100 pontos de altura.
            if let q = quadroOriginal { janelaPrincipal?.setFrame(q, display: false) }
            estado.modoDemo = anterior.modo
            for s in Secao.allCases { estado.definirOcultar(anterior.ocultas.contains(s), em: s) }
            // Em captura nada é publicado para os widgets (ver PublicadorWidget), então não há o que limpar.
        }
        estado.definirOcultarTudo(false)
        estado.ativarDemo()
        // Janela grande para a página inteira caber na foto.
        janelaPrincipal?.setFrame(NSRect(x: 40, y: 40, width: 1440, height: 1700), display: true)
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        for pagina in Pagina.allCases {
            estado.pagina = pagina
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            salvar(nome: "mac-\(pagina.rawValue)", em: destino)
        }
        // Valores ocultos (modo privacidade).
        estado.pagina = .visaoGeral
        estado.definirOcultarTudo(true)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        salvar(nome: "mac-visaoGeral-oculto", em: destino)

        restaurar()
        try? "ok".write(to: destino.appendingPathComponent("FIM.txt"), atomically: true, encoding: .utf8)
        NSApplication.shared.terminate(nil)
    }

    private static func salvar(nome: String, em pasta: URL) {
        guard let janela = NSApplication.shared.windows.first(where: { $0.isVisible && $0.contentView != nil && !($0 is NSPanel) }),
              let vista = janela.contentView else { return }
        guard let rep = vista.bitmapImageRepForCachingDisplay(in: vista.bounds) else { return }
        vista.cacheDisplay(in: vista.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: pasta.appendingPathComponent("\(nome).png"))
        }
    }
}
#endif
