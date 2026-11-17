import SwiftData
import SwiftUI
import PrumoCore

// Conferir categorias: cada loja dos últimos meses e onde os gastos dela caíram. Você bate o olho,
// toca na que está errada, e a escolha vira regra (as anteriores são arrumadas e as próximas já nascem certas).

// MARK: - Aprender com a correção

/// Cria ou atualiza a regra e aplica a categoria nos lançamentos parecidos que ainda não foram corrigidos à mão.
enum Aprendizado {
    /// Casa como o categorizador casa a regra (palavra inteira no texto normalizado) ou pela chave da loja,
    /// que pode ter perdido um número no meio ("Loja 123 Centro" → "loja centro").
    static func casa(_ l: Lancamento, _ padrao: String) -> Bool {
        let texto = Texto.normalizar(l.descricao + " " + (l.estabelecimento ?? ""))
        return Categorizador.casaPadrao(texto, padrao) || l.chaveDeLoja == padrao
    }

    /// Lançamentos não corrigidos à mão que casam com o padrão, fora o `excluindo`.
    static func parecidos(_ padrao: String, em lancamentos: [Lancamento], excluindo: Lancamento? = nil) -> [Lancamento] {
        guard !padrao.isEmpty else { return [] }
        return lancamentos.filter { l in
            guard !l.categoriaManual, l !== excluindo else { return false }
            return casa(l, padrao)
        }
    }

    /// Devolve quantos lançamentos mudaram. Padrão curto ou vazio ("Pix enviado") não vira regra.
    @MainActor @discardableResult
    static func lembrar(padrao: String, categoria chave: String, contexto: ModelContext, regras: [Regra],
                        excluindo: Lancamento? = nil) -> Int {
        guard !padrao.isEmpty, padrao.count >= 3 else { return 0 }
        let neutro = Categorias.info(chave).grupo == .neutro
        if let existente = regras.first(where: { $0.padrao == padrao }) {
            existente.categoriaChave = chave
            existente.marcarInterno = neutro
        } else {
            contexto.insert(Regra(padrao: padrao, categoriaChave: chave, marcarInterno: neutro))
        }
        let todos = (try? contexto.fetch(FetchDescriptor<Lancamento>())) ?? []
        let alvo = parecidos(padrao, em: todos, excluindo: excluindo)
        for l in alvo {
            l.categoriaChave = chave
            if !l.internoManual { l.interno = neutro }
            l.atualizadoEm = Date()
        }
        return alvo.count
    }
}

// MARK: - Peças

/// Uma loja: nome, categoria atual (com o ponto na cor) e o total.
struct LinhaLoja: View {
    let loja: LojaConferida

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(loja.nome).font(.body).lineLimit(1)
                    if loja.confianca < 50 { Selo(texto: "Incerto", cor: Tema.ambar) }
                }
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: loja.categoria.corHex)).frame(width: 6, height: 6)
                    Text("\(loja.categoria.nome) · \(loja.vezes) \(loja.vezes == 1 ? "vez" : "vezes")")
                        .font(.caption).foregroundStyle(Tema.secundario).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Valor(centavos: loja.totalCentavos).font(.numero(16, .medium))
            Seta()
        }
        .contentShape(Rectangle())
    }
}

/// A lista de lojas, uma linha por loja; tocar chama `aoEscolher`.
struct ListaLojas: View {
    let lojas: [LojaConferida]
    let aoEscolher: (LojaConferida) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(lojas) { loja in
                Button { aoEscolher(loja) } label: { LinhaLoja(loja: loja).padding(.vertical, 10) }
                    .buttonStyle(EstiloToque())
                if loja.id != lojas.last?.id { Fio() }
            }
        }
    }
}

/// Seção de "Gastos do mês": as três lojas que mais merecem olhar e o atalho para todas.
struct SecaoConferir: View {
    @Environment(\.conferencia) private var conferencia
    @State private var lojas: [LojaConferida]?
    @State private var escolhendo: LojaConferida?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CabecalhoSecao(titulo: "Conferir categorias") {
                if (lojas?.count ?? 0) > 3 {
                    NavigationLink(value: Destino.conferir) { RotuloLink(texto: "Ver todas") }.buttonStyle(.plain)
                }
            }
            if let lojas {
                if lojas.isEmpty {
                    EstadoVazio(titulo: "Nada para conferir", texto: "Quando houver gastos, as lojas aparecem aqui.")
                } else {
                    Text("Onde cada loja caiu nos últimos 12 meses. Toque na que estiver errada: o app aprende e arruma as anteriores.")
                        .font(.caption).foregroundStyle(Tema.secundario).fixedSize(horizontal: false, vertical: true)
                    ListaLojas(lojas: Array(lojas.prefix(3))) { escolhendo = $0 }
                }
            } else {
                Text("Conferindo…").font(.caption).foregroundStyle(Tema.terciario)
            }
        }
        // Calculado depois do primeiro quadro, para a entrada da tela não esperar.
        .task(id: conferencia.versao) { lojas = conferencia.lojas }
        .sheet(item: $escolhendo) { loja in
            NavigationStack { EscolherCategoriaView(loja: loja) }
                #if os(macOS)
                .frame(minWidth: 460, minHeight: 560)
                #endif
        }
    }
}

// MARK: - Tela cheia

struct ConferirView: View {
    @Environment(\.conferencia) private var conferencia
    @State private var lojas: [LojaConferida] = []
    @State private var busca = ""
    @State private var modo: ModoConferencia = .revisar
    @State private var escolhendo: LojaConferida?

    enum ModoConferencia: Hashable { case revisar, porCategoria }

    private var filtradas: [LojaConferida] {
        let q = Texto.normalizar(busca)
        guard !q.isEmpty else { return lojas }
        return lojas.filter { Texto.normalizar($0.nome + " " + $0.categoria.nome).contains(q) }
    }

    var body: some View {
        let lista = filtradas
        List {
            Section {
                Text("Onde cada loja caiu nos últimos 12 meses. Toque na que estiver errada: a escolha vira regra, arruma as anteriores e vale para as próximas.")
                    .font(.footnote).foregroundStyle(Tema.secundario)
                Seletor(opcoes: [OpcaoSeletor(valor: ModoConferencia.revisar, titulo: "Para revisar"),
                                 OpcaoSeletor(valor: ModoConferencia.porCategoria, titulo: "Por categoria")],
                        selecionado: $modo)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if lista.isEmpty {
                EstadoVazio(titulo: "Nada encontrado", texto: lojas.isEmpty ? "Quando houver gastos, as lojas aparecem aqui." : "Tente outro nome.")
                    .listRowBackground(Color.clear)
            } else {
                switch modo {
                case .revisar:
                    Section {
                        ForEach(lista) { loja in linha(loja) }
                    } header: {
                        Text("\(lista.count) lojas · as que o app menos tem certeza primeiro").rotulo()
                    }
                case .porCategoria:
                    ForEach(porCategoria(lista), id: \.categoria.chave) { grupo in
                        Section {
                            ForEach(grupo.lojas) { loja in linha(loja) }
                        } header: {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: grupo.categoria.corHex)).frame(width: 6, height: 6)
                                Text("\(Categorias.area(de: grupo.categoria.chave).nome) · \(grupo.categoria.nome)").rotulo()
                                Spacer()
                                Text("\(grupo.lojas.count)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Tema.terciario)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Conferir categorias")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $busca, prompt: "Buscar loja ou categoria")
        .task(id: conferencia.versao) { lojas = conferencia.lojas }
        .sheet(item: $escolhendo) { loja in
            NavigationStack { EscolherCategoriaView(loja: loja) }
                #if os(macOS)
                .frame(minWidth: 460, minHeight: 560)
                #endif
        }
    }

    private func linha(_ loja: LojaConferida) -> some View {
        Button { escolhendo = loja } label: { LinhaLoja(loja: loja) }
            .buttonStyle(.plain)
            .listRowBackground(Tema.superficie)
    }

    /// Agrupa por categoria, na ordem das áreas e das categorias do app; dentro, por nome.
    private func porCategoria(_ lista: [LojaConferida]) -> [(categoria: CategoriaInfo, lojas: [LojaConferida])] {
        let grupos = Dictionary(grouping: lista, by: \.categoriaChave)
        return Categorias.todas.compactMap { info in
            guard let lojas = grupos[info.chave] else { return nil }
            return (info, lojas.sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending })
        }
    }
}

// MARK: - Escolher a categoria de uma loja

struct EscolherCategoriaView: View {
    let loja: LojaConferida
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Query private var regras: [Regra]

    private var neutras: [CategoriaInfo] { Categorias.todas.filter { $0.grupo == .neutro } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loja.nome).font(.title3.weight(.semibold))
                    Text("\(loja.vezes) \(loja.vezes == 1 ? "lançamento" : "lançamentos") · hoje em \(loja.categoria.nome)")
                        .font(.caption).foregroundStyle(Tema.secundario)
                    Valor(centavos: loja.totalCentavos).numeroGrande()
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }
            ForEach(Categorias.despesasPorArea, id: \.area.chave) { grupo in
                Section(grupo.area.nome) {
                    ForEach(grupo.categorias) { c in opcao(c) }
                }
            }
            Section("Movimentações (não é gasto)") {
                ForEach(neutras) { c in opcao(c) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Categoria")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }.semCapsulaNoMac() }
    }

    private func opcao(_ c: CategoriaInfo) -> some View {
        Button { escolher(c.chave) } label: {
            HStack(spacing: 10) {
                Circle().fill(Color(hex: c.corHex)).frame(width: 8, height: 8)
                Text(c.nome)
                Spacer()
                if c.chave == loja.categoriaChave {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Tema.acento)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Tema.superficie)
    }

    private func escolher(_ chave: String) {
        if chave != loja.categoriaChave {
            Aprendizado.lembrar(padrao: loja.chave, categoria: chave, contexto: contexto, regras: regras)
            try? contexto.save()
        }
        dismiss()
    }
}
