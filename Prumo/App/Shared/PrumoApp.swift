import SwiftData
import SwiftUI
import PrumoCore

@main
struct PrumoApp: App {
    @State private var estado = EstadoApp()
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
        janelaPrincipal
        #if os(macOS)
        Settings {
            NavigationStack { AjustesView() }
                .environment(estado)
                .modelContainer(estado.container)
                .tint(Tema.acento)
                .preferredColorScheme(.dark)
                .frame(width: 560, height: 620)
        }
        MenuBarExtra {
            MenuBarConteudo()
                .environment(estado)
                .modelContainer(estado.container)
                .preferredColorScheme(.dark)
        } label: {
            Image(systemName: "p.circle.fill")
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    private var janelaPrincipal: some Scene {
        WindowGroup {
            RaizView()
                .environment(estado)
                .modelContainer(estado.container)
                .task {
                    estado.iniciar()
                    #if os(macOS) && DEBUG
                    await CapturaDeTelas.executarSeSolicitado(estado)
                    #endif
                }
                .onChange(of: fase) { _, nova in
                    switch nova {
                    case .background: estado.publicarWidgets()
                    case .active:
                        estado.buscarCDI()
                        Task { await estado.atualizarSeNecessario() }
                    default: break
                    }
                }
                #if os(macOS)
                .frame(minWidth: 1160, minHeight: 680)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1360, height: 880)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button("Atualizar bancos") { Task { await estado.atualizar() } }
                    .keyboardShortcut("r", modifiers: [.command])
            }
            CommandMenu("Ir para") {
                ForEach(Array(Pagina.allCases.enumerated()), id: \.element) { i, p in
                    Button(p.titulo) { estado.pagina = p }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [.command])
                }
            }
        }
        #endif
    }
}
