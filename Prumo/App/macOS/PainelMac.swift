import SwiftData
import SwiftUI
import PrumoCore

// O Mac é organizado como um caderno de páginas (a referência é o Notion):
// barra lateral com as páginas, e cada página com título grande, propriedades, blocos
// (chamadas, números em colunas, seções que recolhem) e bases em tabela com etiquetas e
// rodapé de contagem e soma. As cores continuam as do Perity: preto, branco e limão.
// As páginas ficam em PaginasMac.swift; aqui estão a moldura e as peças.

struct PainelMac: View {
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        HStack(spacing: 0) {
            BarraLateralMac()
            Rectangle().fill(Tema.linha).frame(width: 1)
            NavigationStack {
                pagina
                    .id(estado.pagina)
                    // O olho é por página: Investimentos e Fixos têm o seu; as demais seguem o do Início.
                    .environment(\.valoresOcultos, estado.oculta(estado.pagina.secao ?? .inicio))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Tema.fundo)
                    .navigationTitle("Perity")
                    .toolbar {
                        ToolbarItem(placement: .navigation) { Migalhas(pagina: estado.pagina) }.semCapsula()
                        // Atualizar, ocultar valores e ajustes ficam no pé da barra lateral.
                        ToolbarItem(placement: .primaryAction) { IndicadorAtualizacao().padding(.trailing, 6) }.semCapsula()
                    }
            }
        }
        .background(Tema.fundo)
    }

    @ViewBuilder private var pagina: some View {
        switch estado.pagina {
        case .visaoGeral: VisaoGeralMac()
        case .contas: ContasMac()
        case .cartoes: CartoesMac()
        case .gastos: GastosMac()
        case .lancamentos: LancamentosMac()
        case .fixos: FixosMac()
        case .investimentos: InvestimentosMac()
        }
    }
}

/// "Perity / Gastos do mês" no topo da janela.
private struct Migalhas: View {
    let pagina: Pagina

    var body: some View {
        HStack(spacing: 6) {
            Text("Perity").foregroundStyle(Tema.secundario)
            Text("/").foregroundStyle(Tema.terciario)
            Text(pagina.titulo).foregroundStyle(Tema.texto)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 6)
    }
}

// MARK: - Barra lateral

struct BarraLateralMac: View {
    @Environment(EstadoApp.self) private var estado

    private let grupos: [(titulo: String?, paginas: [Pagina])] = [
        (nil, [.visaoGeral]),
        ("Dinheiro", [.contas, .cartoes]),
        ("Mês", [.gastos, .lancamentos, .fixos]),
        ("Patrimônio", [.investimentos]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Marca(tamanho: 16)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .padding(.bottom, 10)

            ForEach(Array(grupos.enumerated()), id: \.offset) { _, grupo in
                if let t = grupo.titulo {
                    Text(t)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Tema.terciario)
                        .padding(.horizontal, 10)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                }
                ForEach(grupo.paginas) { p in
                    ItemLateral(titulo: p.titulo, icone: p.icone, ativo: estado.pagina == p,
                                atalho: "⌘\((Pagina.allCases.firstIndex(of: p) ?? 0) + 1)") { estado.pagina = p }
                }
            }
            Spacer(minLength: 12)
            if estado.buscaBancos && estado.temCredenciais && !estado.modoDemo {
                ItemLateral(titulo: estado.atualizacao == .atualizando ? "Atualizando…" : "Atualizar bancos",
                            icone: "arrow.clockwise", ativo: false, atalho: "⌘R") { Task { await estado.atualizar() } }
            }
            // O olho é o da página aberta; páginas sem aba própria (Contas, Cartões…) seguem o Início.
            let secaoDaPagina = estado.pagina.secao ?? .inicio
            ItemLateral(titulo: estado.oculta(secaoDaPagina) ? "Mostrar valores" : "Ocultar valores",
                        icone: estado.oculta(secaoDaPagina) ? "eye.slash" : "eye", ativo: false) { estado.alternarOcultar(secaoDaPagina) }
            SettingsLink {
                RotuloLateral(titulo: "Ajustes", icone: "gearshape", ativo: false, atalho: "⌘,")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(width: 232)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Tema.superficie)
    }
}

private struct RotuloLateral: View {
    let titulo: String
    let icone: String
    let ativo: Bool
    var atalho: String?
    @State private var sobre = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icone)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundStyle(ativo ? Tema.acento : Tema.secundario)
            Text(titulo)
                .font(.system(size: 13.5, weight: ativo ? .medium : .regular))
                .foregroundStyle(ativo ? Tema.texto : Tema.secundario)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let atalho {
                Text(atalho).font(.system(size: 11, design: .monospaced)).foregroundStyle(Tema.terciario)
                    .opacity(sobre ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(ativo ? Tema.elevada : (sobre ? Color.white.opacity(0.05) : Color.clear),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { sobre = $0 }
        .animation(Movimento.rapida, value: sobre)
        .animation(Movimento.rapida, value: ativo)
    }
}

private struct ItemLateral: View {
    let titulo: String
    let icone: String
    let ativo: Bool
    var atalho: String?
    let acao: () -> Void

    var body: some View {
        Button(action: acao) { RotuloLateral(titulo: titulo, icone: icone, ativo: ativo, atalho: atalho) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(ativo ? .isSelected : [])
    }
}

// MARK: - Página

/// A moldura de uma página: título grande, propriedades (rótulo e valor) e os blocos, em uma coluna centralizada.
struct PaginaMac<Conteudo: View>: View {
    let titulo: String
    var propriedades: [(rotulo: String, valor: String)] = []
    @ViewBuilder var conteudo: () -> Conteudo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(titulo).font(.system(size: 36, weight: .bold)).tracking(-0.9)
                    if !propriedades.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(propriedades.enumerated()), id: \.offset) { _, p in
                                HStack(alignment: .firstTextBaseline, spacing: 0) {
                                    Text(p.rotulo).foregroundStyle(Tema.secundario).frame(width: 130, alignment: .leading)
                                    TextoPrivado(p.valor).foregroundStyle(Tema.texto)
                                }
                                .font(.system(size: 13))
                            }
                        }
                    }
                }
                .padding(.top, 40)
                .entrada(0)
                conteudo()
            }
            .padding(.horizontal, 56)
            .padding(.bottom, 72)
            .frame(maxWidth: 1080, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .rolagemDeTeste()
        .background(Tema.fundo)
        .entradaDeTela()
    }
}

/// Um título de seção que recolhe e abre o que vem abaixo, como os "toggles" do Notion.
struct SecaoMac<Conteudo: View, Lado: View>: View {
    let titulo: String
    var ordem = 2
    @ViewBuilder var lado: () -> Lado
    @ViewBuilder var conteudo: () -> Conteudo
    @State private var aberta = true
    @Environment(\.accessibilityReduceMotion) private var reduzir

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Button {
                    withAnimation(reduzir ? nil : Movimento.rapida) { aberta.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Tema.terciario)
                            .rotationEffect(.degrees(aberta ? 90 : 0))
                            .frame(width: 14)
                        Text(titulo).font(.system(size: 19, weight: .semibold)).tracking(-0.3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(aberta ? "Recolher" : "Abrir")
                Spacer(minLength: 8)
                if aberta { lado() }
            }
            if aberta { conteudo() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 36)
        .entrada(ordem)
    }
}

extension SecaoMac where Lado == EmptyView {
    init(titulo: String, ordem: Int = 2, @ViewBuilder conteudo: @escaping () -> Conteudo) {
        self.titulo = titulo
        self.ordem = ordem
        self.lado = { EmptyView() }
        self.conteudo = conteudo
    }
}

// MARK: - Blocos

/// Um número em destaque dentro de uma fileira de colunas. Com `acao`, leva para a página do detalhe.
struct MetricaMac: View {
    let rotulo: String
    var centavos: Int?
    var texto: String?
    var apoio: String?
    var cor: Color = Tema.texto
    var acao: (() -> Void)?
    @State private var sobre = false

    var body: some View {
        Group {
            if let acao {
                Button(action: acao) { corpo }.buttonStyle(.plain)
            } else {
                corpo
            }
        }
        .onHover { sobre = $0 }
    }

    private var corpo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rotulo).rotulo().lineLimit(1)
                Spacer(minLength: 4)
                if acao != nil { Seta().opacity(sobre ? 1 : 0.4) }
            }
            if let centavos {
                NumeroHeroi(centavos: centavos, tamanho: 30, cor: cor)
            } else if let texto {
                TextoPrivado(texto).font(.numero(30)).tracking(-0.9).foregroundStyle(cor).lineLimit(1).minimumScaleFactor(0.5)
            }
            if let apoio {
                TextoPrivado(apoio).font(.system(size: 12)).foregroundStyle(Tema.secundario).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(acao != nil && sobre ? Tema.elevada : Tema.superficie,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .animation(Movimento.rapida, value: sobre)
    }
}

/// Um bloco de aviso com fundo: o ponto colorido, a frase e o complemento.
struct ChamadaMac: View {
    var cor: Color = Tema.secundario
    var rotulo: String?
    let titulo: String
    var texto: String?
    var acao: (() -> Void)?
    @State private var sobre = false

    var body: some View {
        Group {
            if let acao {
                Button(action: acao) { corpo }.buttonStyle(.plain)
            } else {
                corpo
            }
        }
        .onHover { sobre = $0 }
    }

    private var corpo: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(cor).frame(width: 7, height: 7).padding(.top, rotulo == nil ? 6 : 4).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let rotulo { Text(rotulo).rotulo() }
                TextoPrivado(titulo).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                if let texto, !texto.isEmpty {
                    TextoPrivado(texto).font(.system(size: 13)).foregroundStyle(Tema.secundario).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if acao != nil { Seta().padding(.top, 4).opacity(sobre ? 1 : 0.4) }
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(acao != nil && sobre ? Tema.elevada : Tema.superficie,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .animation(Movimento.rapida, value: sobre)
    }
}

/// Etiqueta de uma propriedade (categoria, forma de pagamento, situação), com um ponto de cor opcional.
struct EtiquetaMac: View {
    let texto: String
    var cor: Color?

    var body: some View {
        HStack(spacing: 5) {
            if let cor { Circle().fill(cor).frame(width: 6, height: 6) }
            Text(texto).font(.system(size: 12)).lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .foregroundStyle(Tema.texto.opacity(0.86))
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

extension EtiquetaMac {
    /// A etiqueta de uma categoria, com o ponto na cor dela.
    init(categoria chave: String) {
        let info = Categorias.info(chave)
        self.init(texto: info.nome, cor: Color(hex: info.corHex))
    }
}

// MARK: - Bases (tabelas)

/// Uma coluna de uma base: o nome da propriedade, o ícone do tipo e a largura (nil = ocupa o que sobrar).
struct ColunaBase {
    let titulo: String
    var icone = "textformat"
    var largura: CGFloat?
    var aDireita = false

    var alinhamento: Alignment { aDireita ? .trailing : .leading }
}

extension View {
    /// Põe a célula na largura e no alinhamento da coluna.
    func celula(_ c: ColunaBase) -> some View {
        frame(maxWidth: c.largura == nil ? .infinity : nil, alignment: c.alinhamento)
            .frame(width: c.largura, alignment: c.alinhamento)
    }
}

/// O título de uma base, com a contagem e, se houver, as visões ("Categorias | Áreas").
struct TituloBase<Lado: View>: View {
    let titulo: String
    var icone = "tablecells"
    @ViewBuilder var lado: () -> Lado

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icone).font(.system(size: 12)).foregroundStyle(Tema.secundario)
            Text(titulo).font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 8)
            lado()
        }
        .padding(.bottom, 2)
    }
}

extension TituloBase where Lado == EmptyView {
    init(titulo: String, icone: String = "tablecells") {
        self.titulo = titulo
        self.icone = icone
        self.lado = { EmptyView() }
    }
}

/// As visões de uma base: abas pequenas, a escolhida sublinhada.
struct VisoesBase<Valor: Hashable>: View {
    let opcoes: [OpcaoSeletor<Valor>]
    @Binding var selecionada: Valor
    @Namespace private var espaco

    var body: some View {
        HStack(spacing: 16) {
            ForEach(opcoes) { o in
                let ativa = o.valor == selecionada
                Button { withAnimation(Movimento.rapida) { selecionada = o.valor } } label: {
                    Text(o.titulo)
                        .font(.system(size: 13, weight: ativa ? .medium : .regular))
                        .foregroundStyle(ativa ? Tema.texto : Tema.secundario)
                        .padding(.vertical, 5)
                        .overlay(alignment: .bottom) {
                            if ativa {
                                Rectangle().fill(Tema.texto).frame(height: 1.5).matchedGeometryEffect(id: "visao", in: espaco)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CabecalhoBase: View {
    let colunas: [ColunaBase]
    /// Espaço antes da primeira coluna (para a caixinha de marcar).
    var recuo: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Fio()
            HStack(spacing: 12) {
                if recuo > 0 { Color.clear.frame(width: recuo, height: 1) }
                ForEach(Array(colunas.enumerated()), id: \.offset) { _, c in
                    HStack(spacing: 5) {
                        Image(systemName: c.icone).font(.system(size: 10))
                        Text(c.titulo).font(.system(size: 12)).lineLimit(1)
                    }
                    .foregroundStyle(Tema.secundario)
                    .celula(c)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            Fio()
        }
    }
}

/// Uma linha de base: realça ao passar o ponteiro e, se tiver `acao`, abre o item.
struct LinhaBase<Conteudo: View>: View {
    var acao: (() -> Void)?
    @ViewBuilder var conteudo: () -> Conteudo
    @State private var sobre = false

    var body: some View {
        Group {
            if let acao {
                Button(action: acao) { corpo }.buttonStyle(.plain)
            } else {
                corpo
            }
        }
        .onHover { sobre = $0 }
    }

    private var corpo: some View {
        HStack(spacing: 12) { conteudo() }
            .font(.system(size: 13.5))
            .padding(.horizontal, 8)
            .frame(minHeight: 38)
            .background(sobre ? Color.white.opacity(0.045) : Color.clear)
            .overlay(alignment: .bottom) { Fio() }
            .contentShape(Rectangle())
    }
}

/// O rodapé de uma base: "CONTAGEM 16 · SOMA R$ 10.459,82", alinhado à direita, como nas tabelas do Notion.
struct RodapeBase: View {
    let itens: [(rotulo: String, valor: String)]

    var body: some View {
        HStack(spacing: 24) {
            Spacer(minLength: 0)
            ForEach(Array(itens.enumerated()), id: \.offset) { _, i in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(i.rotulo)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(Tema.terciario)
                    TextoPrivado(i.valor).font(.system(size: 13)).monospacedDigit().foregroundStyle(Tema.texto)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
    }
}

/// "+ Novo": a linha clara no fim de uma base.
struct LinhaNova: View {
    let titulo: String
    let acao: () -> Void
    @State private var sobre = false

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                Text(titulo).font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .foregroundStyle(sobre ? Tema.texto : Tema.secundario)
            .padding(.horizontal, 8)
            .frame(height: 34)
            .background(sobre ? Color.white.opacity(0.045) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { sobre = $0 }
    }
}

/// Botão discreto de página ("Colar uma lista"): texto com borda fina.
struct BotaoDePagina: View {
    let titulo: String
    var icone: String?
    var principal = false
    let acao: () -> Void
    @State private var sobre = false

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 6) {
                if let icone { Image(systemName: icone).font(.system(size: 11, weight: .medium)) }
                Text(titulo).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .foregroundStyle(principal ? Tema.sobreAcento : Tema.texto)
            .background(principal ? Tema.acento.opacity(sobre ? 0.86 : 1) : (sobre ? Tema.elevada : Tema.superficie),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { sobre = $0 }
    }
}

/// Folha do Mac para abrir um item (como a "espiada" do Notion), com botão de fechar.
struct FolhaMac<Conteudo: View>: View {
    var comFechar = true
    @ViewBuilder var conteudo: () -> Conteudo
    @Environment(\.dismiss) private var dismiss
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        NavigationStack {
            conteudo()
                .toolbar {
                    if comFechar {
                        ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }.semCapsulaNoMac()
                    }
                }
        }
        // A folha abre fora da página: recebe o olho da página atual para não mostrar o que está oculto.
        .environment(\.valoresOcultos, estado.oculta(estado.pagina.secao ?? .inicio))
        .frame(minWidth: 520, minHeight: 600)
        .preferredColorScheme(.dark)
        .tint(Tema.acento)
    }
}
