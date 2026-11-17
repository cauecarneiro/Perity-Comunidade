import SwiftData
import SwiftUI
import PrumoCore

/// As três áreas do app. Contas, cartões e lançamentos não são áreas: são o detalhe de um número do Início.
enum Secao: String, CaseIterable, Identifiable, Hashable {
    case inicio, investimentos, fixos
    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .inicio: "Início"
        case .investimentos: "Investimentos"
        case .fixos: "Fixos"
        }
    }

    var icone: String {
        switch self {
        case .inicio: "house"
        case .investimentos: "chart.line.uptrend.xyaxis"
        case .fixos: "checklist"
        }
    }
}

/// As páginas do Mac (barra lateral). No iPhone, contas, cartões, gastos e lançamentos são o detalhe do Início.
enum Pagina: String, CaseIterable, Identifiable, Hashable {
    case visaoGeral, contas, cartoes, gastos, lancamentos, fixos, investimentos
    var id: String { rawValue }

    init(_ secao: Secao) {
        switch secao {
        case .inicio: self = .visaoGeral
        case .investimentos: self = .investimentos
        case .fixos: self = .fixos
        }
    }

    var titulo: String {
        switch self {
        case .visaoGeral: "Visão geral"
        case .contas: "Contas"
        case .cartoes: "Cartões"
        case .gastos: "Gastos do mês"
        case .lancamentos: "Lançamentos"
        case .fixos: "Fixos"
        case .investimentos: "Investimentos"
        }
    }

    var icone: String {
        switch self {
        case .visaoGeral: "house"
        case .contas: "building.columns"
        case .cartoes: "creditcard"
        case .gastos: "chart.bar"
        case .lancamentos: "list.bullet"
        case .fixos: "checklist"
        case .investimentos: "chart.line.uptrend.xyaxis"
        }
    }

    /// A aba do iPhone que corresponde a esta página, quando há uma.
    var secao: Secao? {
        switch self {
        case .visaoGeral: .inicio
        case .investimentos: .investimentos
        case .fixos: .fixos
        default: nil
        }
    }
}

struct FiltroLancamentos: Hashable {
    var categoria: String?
    var contaID: String?
    /// Qualquer data dentro do mês desejado.
    var mes: Date?
    var apenasSemCategoria = false
    var titulo: String?
    /// Só estes lançamentos (ex.: as cobranças de um fixo), em qualquer período.
    var externalIDs: Set<String>?
    /// Texto já na busca ao abrir (ex.: como o fixo aparece no extrato).
    var busca: String?
}

enum Destino: Hashable {
    case contas
    case cartoes
    case analise
    case lancamentos(FiltroLancamentos)
    case conta(String)
    case avisos
    case conferir

    #if DEBUG
    /// Fotos das telas: `-prumo-destino contas|cartoes|analise|lancamentos|avisos|conferir` abre direto no detalhe.
    static var pedidoNaLinhaDeComando: Destino? {
        switch UserDefaults.standard.string(forKey: "prumo-destino") {
        case "contas": .contas
        case "cartoes": .cartoes
        case "analise": .analise
        case "lancamentos": .lancamentos(FiltroLancamentos())
        case "avisos": .avisos
        case "conferir": .conferir
        default: nil
        }
    }
    #endif
}

/// Pilha de navegação com os destinos comuns já registrados.
struct PilhaPrumo<Conteudo: View>: View {
    var abreDestinoPedido = false
    @ViewBuilder var conteudo: () -> Conteudo
    @State private var caminho: [Destino] = []
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $caminho) {
            conteudo()
                .navigationDestination(for: Destino.self) { destino in
                    Group {
                        switch destino {
                        case .contas: ContasDetalheView()
                        case .cartoes: CartoesDetalheView()
                        case .analise: AnaliseView()
                        case .lancamentos(let f): LancamentosView(filtroInicial: f)
                        case .conta(let id): DetalheContaView(contaID: id)
                        case .avisos: TodosAvisosView()
                        case .conferir: ConferirView()
                        }
                    }
                    .environment(\.espacoZoom, zoom)
                }
        }
        .environment(\.espacoZoom, zoom)
        #if DEBUG
        .onAppear {
            if abreDestinoPedido, caminho.isEmpty, let d = Destino.pedidoNaLinhaDeComando { caminho = [d] }
        }
        #endif
    }
}

struct RaizView: View {
    @Environment(EstadoApp.self) private var estado
    @Environment(\.scenePhase) private var fase
    @Query private var contas: [Conta]
    @Query private var conexoes: [Conexao]
    @State private var aberturaNaTela = true

    private var semDados: Bool { contas.isEmpty && conexoes.isEmpty && !estado.modoDemo }

    var body: some View {
        Group {
            if semDados {
                BoasVindasView()
            } else {
                ConteudoPrumo()
            }
        }
        .overlay {
            if estado.comAbertura && aberturaNaTela {
                AberturaView(aoSair: { estado.abrindo = false }, aoSumir: { aberturaNaTela = false })
            }
        }
        #if os(iOS)
        // Esconde os valores na tela de apps recentes.
        .blur(radius: fase == .active ? 0 : 24)
        #endif
        .tint(Tema.acento)
        .preferredColorScheme(.dark)
        .alert("Atenção", isPresented: Binding(get: { estado.avisoArmazenamento != nil },
                                                set: { if !$0 { estado.avisoArmazenamento = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(estado.avisoArmazenamento ?? "")
        }
    }

}

/// O app em si, com os números calculados uma vez acima das telas (ver Dados.swift).
/// Não depende de nada da raiz: quando a abertura sai ou a janela ganha foco, a raiz se redesenha e esta parte não.
private struct ConteudoPrumo: View {
    var body: some View {
        #if os(macOS)
        PainelMac().dadosDoPerity()
        #else
        AbasPrumo().dadosDoPerity()
        #endif
    }
}

#if os(iOS)
/// iPhone: três abas. Fica em uma tela própria para que trocar de aba não refaça nada acima dela.
struct AbasPrumo: View {
    @Environment(EstadoApp.self) private var estado
    @State private var mostrarAjustes = false

    var body: some View {
        @Bindable var estado = estado
        TabView(selection: $estado.secao) {
            ForEach(Secao.allCases) { s in
                PilhaPrumo(abreDestinoPedido: s == .inicio) { conteudo(s) }
                    // O olho da aba vale para a pilha inteira: os detalhes do Início (contas, cartões, gastos) seguem o Início.
                    .environment(\.valoresOcultos, estado.oculta(s))
                    .tabItem { Label(s.titulo, systemImage: s.icone) }
                    .tag(s)
            }
        }
        .sheet(isPresented: $mostrarAjustes) {
            NavigationStack { AjustesView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { mostrarAjustes = false } }.semCapsulaNoMac() } }
                .tint(Tema.acento)
                .preferredColorScheme(.dark)
        }
        .environment(\.abrirAjustes, { mostrarAjustes = true })
        // Desenha um gráfico invisível enquanto a abertura toca: a primeira tela com gráfico não espera o carregamento.
        .background { AquecimentoDeGraficos() }
    }

    @ViewBuilder private func conteudo(_ s: Secao) -> some View {
        switch s {
        case .inicio: InicioView()
        case .investimentos: InvestimentosView()
        case .fixos: FixosView()
        }
    }
}
#endif

// Ação para abrir os ajustes a partir de qualquer tela (no Mac eles têm janela própria).
private struct AbrirAjustesChave: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var abrirAjustes: (() -> Void)? {
        get { self[AbrirAjustesChave.self] }
        set { self[AbrirAjustesChave.self] = newValue }
    }
}

/// Botões comuns da barra superior. No iPhone: ocultar valores e ajustes (para atualizar, puxe o Início para baixo).
/// No Mac: atualizar e ocultar valores. O olho é o da página (`secao`): fechar o de Investimentos não mexe no Início.
/// Só o ícone, discreto, sem a cápsula de vidro que o iOS 26 põe em volta dos botões da barra.
struct BarraPrumo: ToolbarContent {
    var secao: Secao = .inicio
    @Environment(EstadoApp.self) private var estado
    @Environment(\.abrirAjustes) private var abrirAjustes

    private var oculto: Bool { estado.oculta(secao) }

    var body: some ToolbarContent {
        #if os(macOS)
        if estado.buscaBancos && estado.temCredenciais && !estado.modoDemo {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await estado.atualizar() }
                } label: {
                    Group {
                        if estado.atualizacao == .atualizando { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .modifier(IconeDeBarra())
                }
                .buttonStyle(.plain)
                .help("Atualizar agora")
                .accessibilityLabel("Atualizar bancos")
            }
            .semCapsula()
        }
        #endif
        ToolbarItem(placement: .primaryAction) {
            Button {
                estado.alternarOcultar(secao)
            } label: {
                Image(systemName: oculto ? "eye.slash" : "eye")
                    .contentTransition(.symbolEffect(.replace))
                    .modifier(IconeDeBarra())
            }
            .buttonStyle(.plain)
            .help(oculto ? "Mostrar valores" : "Ocultar valores")
            .accessibilityLabel(oculto ? "Mostrar valores" : "Ocultar valores")
        }
        .semCapsula()
        if let abrir = abrirAjustes {
            ToolbarItem(placement: .primaryAction) {
                Button { abrir() } label: {
                    Image(systemName: "gearshape").modifier(IconeDeBarra())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajustes")
            }
            .semCapsula()
        }
    }
}

/// Ícone fino e cinza, com área de toque confortável (44 pt) mesmo sem a cápsula.
struct IconeDeBarra: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Tema.secundario)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

extension ToolbarContent {
    /// Tira a cápsula de vidro do iOS/macOS 26; nas versões anteriores ela não existe.
    @ToolbarContentBuilder func semCapsula() -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }

    /// O mesmo, só no Mac: nas folhas do iPhone os botões de texto continuam como o sistema desenha.
    @ToolbarContentBuilder func semCapsulaNoMac() -> some ToolbarContent {
        #if os(macOS)
        semCapsula()
        #else
        self
        #endif
    }
}

struct BoasVindasView: View {
    @Environment(EstadoApp.self) private var estado
    @State private var configurando = false

    var body: some View {
        ZStack {
            Tema.fundo.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("perity").font(.system(size: 56, weight: .semibold)).tracking(-2.2).foregroundStyle(Tema.texto)
                        Circle().fill(Tema.acento).frame(width: 12, height: 12)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Perity")
                    Text("Quanto você tem, quanto deve no cartão e o que falta pagar. Em uma tela.")
                        .font(.title3).foregroundStyle(Tema.secundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(spacing: 10) {
                    Button("Conectar meus bancos") { configurando = true }
                        .buttonStyle(EstiloPrincipal())
                    Button("Ver com dados de exemplo") { estado.ativarDemo() }
                        .buttonStyle(EstiloSecundario())
                }
                Text("Já usa o Perity em outro aparelho? Seus dados chegam pelo iCloud em instantes. Tudo fica no seu aparelho e no seu iCloud: não existe servidor do Perity.")
                    .font(.footnote).foregroundStyle(Tema.terciario)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
            }
            .padding(24)
            .frame(maxWidth: 440)
        }
        .sheet(isPresented: $configurando) {
            NavigationStack {
                ConectarBancosView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { configurando = false } }.semCapsulaNoMac() }
            }
            .tint(Tema.acento)
            .preferredColorScheme(.dark)
            #if os(macOS)
            .frame(minWidth: 520, minHeight: 560)
            #endif
        }
    }
}
