import SwiftData
import SwiftUI
import PrumoCore

enum PeriodoLista: Hashable, Identifiable {
    case mesAtual, mesAnterior, tresMeses, ano, tudo
    case mes(Date)

    var id: String {
        switch self {
        case .mes(let d): "mes-\(d.timeIntervalSince1970)"
        case .mesAtual: "atual"
        case .mesAnterior: "anterior"
        case .tresMeses: "tres"
        case .ano: "ano"
        case .tudo: "tudo"
        }
    }

    var titulo: String {
        switch self {
        case .mesAtual: "Este mês"
        case .mesAnterior: "Mês passado"
        case .tresMeses: "Últimos 3 meses"
        case .ano: "Este ano"
        case .tudo: "Tudo"
        case .mes(let d): d.mesAno
        }
    }

    func intervalo(hoje: Date) -> (Date, Date) {
        let ini = Datas.inicioDoMes(hoje)
        let amanha = Datas.somar(dias: 1, a: Datas.inicioDoDia(hoje))
        let fimDoMes = Datas.somar(meses: 1, a: ini)
        switch self {
        case .mesAtual: return (ini, max(fimDoMes, amanha))
        case .mesAnterior: return (Datas.somar(meses: -1, a: ini), ini)
        case .tresMeses: return (Datas.somar(meses: -2, a: ini), max(fimDoMes, amanha))
        case .ano:
            let c = Datas.calendario
            let inicioAno = c.date(from: c.dateComponents([.year], from: hoje)) ?? ini
            return (inicioAno, max(fimDoMes, amanha))
        case .tudo: return (.distantPast, .distantFuture)
        case .mes(let d):
            let i = Datas.inicioDoMes(d)
            return (i, Datas.somar(meses: 1, a: i))
        }
    }
}

struct LancamentosView: View {
    @Query(sort: [SortDescriptor(\Lancamento.data, order: .reverse), SortDescriptor(\Lancamento.criadoEm, order: .reverse)])
    private var todos: [Lancamento]
    @Query private var contas: [Conta]

    @State private var busca = ""
    @State private var periodo: PeriodoLista
    @State private var categoria: String?
    @State private var contaID: String?
    @State private var tipo: TipoFiltro = .todos
    @State private var mostrarInternos = false
    @State private var apenasSemCategoria: Bool
    @State private var selecionado: Lancamento?
    @State private var criando = false
    private let titulo: String
    private let externalIDs: Set<String>?

    enum TipoFiltro: String, CaseIterable, Identifiable {
        case todos = "Todos", saidas = "Saídas", entradas = "Entradas"
        var id: String { rawValue }
    }

    init(filtroInicial: FiltroLancamentos) {
        // Cobranças escolhidas ou uma busca pronta: o período abre inteiro, para o histórico aparecer.
        let semPeriodo = filtroInicial.externalIDs != nil || filtroInicial.busca != nil
        _periodo = State(initialValue: filtroInicial.mes.map { PeriodoLista.mes($0) } ?? (semPeriodo ? .tudo : .mesAtual))
        _busca = State(initialValue: filtroInicial.busca ?? "")
        externalIDs = filtroInicial.externalIDs
        _categoria = State(initialValue: filtroInicial.categoria)
        _contaID = State(initialValue: filtroInicial.contaID)
        _apenasSemCategoria = State(initialValue: filtroInicial.apenasSemCategoria)
        titulo = filtroInicial.titulo ?? "Lançamentos"
    }

    private var nomeDasContas: [String: String] {
        Dictionary(contas.map { ($0.externalID, $0.nomeExibicao) }, uniquingKeysWith: { a, _ in a })
    }

    private var cartoes: Set<String> { Analise.idsDeCartao(contas) }

    private var filtrados: [Lancamento] {
        let (ini, fim) = periodo.intervalo(hoje: Date())
        let q = Texto.normalizar(busca)
        return todos.filter { l in
            if let externalIDs, !externalIDs.contains(l.externalID) { return false }
            guard l.conciliadoComID == nil, l.data >= ini, l.data < fim else { return false }
            if !mostrarInternos && (l.interno || l.ignorado) { return false }
            if let c = categoria, l.categoriaChave != c { return false }
            if let c = contaID, l.contaID != c { return false }
            if apenasSemCategoria && !(l.categoriaChave == "outros" || l.categoriaChave == "outras_receitas") { return false }
            switch tipo {
            case .saidas: if l.valorCentavos >= 0 && !cartoes.contains(l.contaID) { return false }
                          if cartoes.contains(l.contaID) && l.valorCentavos > 0 { return false }
            case .entradas: if l.valorCentavos <= 0 || cartoes.contains(l.contaID) { return false }
            case .todos: break
            }
            if !q.isEmpty {
                let alvo = Texto.normalizar(l.descricao + " " + (l.estabelecimento ?? "") + " " + l.categoria.nome + " " + (l.notas ?? ""))
                if !alvo.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        let lista = filtrados
        let grupos = Dictionary(grouping: lista) { Datas.inicioDoDia($0.data) }
        let dias = grupos.keys.sorted(by: >)
        List {
            Section {
                resumoDaLista(lista)
                filtros
            }
            .listRowBackground(Tema.superficie)
            if lista.isEmpty {
                EstadoVazio(titulo: "Nada encontrado", texto: "Ajuste os filtros ou o período.")
                    .listRowBackground(Color.clear)
            }
            ForEach(dias, id: \.self) { dia in
                Section {
                    ForEach(grupos[dia] ?? []) { l in
                        Button { selecionado = l } label: {
                            LinhaLancamento(lancamento: l, nomeConta: nomeDasContas[l.contaID])
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Tema.superficie)
                        .swipeActions(edge: .trailing) {
                            Button { l.ignorado.toggle() } label: {
                                Label(l.ignorado ? "Reativar" : "Ignorar", systemImage: l.ignorado ? "eye" : "eye.slash")
                            }
                            .tint(.gray)
                        }
                        .swipeActions(edge: .leading) {
                            Button { l.interno.toggle(); l.internoManual = true } label: {
                                Label(l.interno ? "É gasto" : "Interno", systemImage: "arrow.left.arrow.right")
                            }
                            .tint(Tema.elevada)
                        }
                    }
                } header: {
                    HStack {
                        Text(tituloDoDia(dia))
                        Spacer()
                        let saldo = (grupos[dia] ?? []).filter { $0.contaParaRelatorios }.reduce(0) { $0 + $1.valorCentavos }
                        if saldo != 0 { Valor(centavos: saldo).font(.system(size: 11, design: .monospaced)) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle(titulo)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $busca, prompt: "Buscar lançamento, categoria ou nota")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { criando = true } label: { Image(systemName: "plus").modifier(IconeDeBarra()) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Novo lançamento")
            }
            .semCapsula()
        }
        .sheet(item: $selecionado) { l in
            NavigationStack { DetalheLancamentoView(lancamento: l) }
                #if os(macOS)
                .frame(minWidth: 460, minHeight: 560)
                #endif
        }
        .sheet(isPresented: $criando) {
            NavigationStack { NovoLancamentoView() }
                #if os(macOS)
                .frame(minWidth: 460, minHeight: 520)
                #endif
        }
    }

    // MARK: Partes

    private func resumoDaLista(_ lista: [Lancamento]) -> some View {
        let validos = lista.filter { $0.contaParaRelatorios }
        let cart = cartoes
        var entrou = 0, saiu = 0
        for l in validos {
            if cart.contains(l.contaID) { saiu += -l.valorCentavos }
            else if l.valorCentavos > 0 { entrou += l.valorCentavos }
            else { saiu += -l.valorCentavos }
        }
        return HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Saiu").rotulo()
                Valor(centavos: saiu).font(.numero(22))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Entrou").rotulo()
                Valor(centavos: entrou).font(.numero(22))
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 4)
    }

    private var filtros: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach([PeriodoLista.mesAtual, .mesAnterior, .tresMeses, .ano, .tudo]) { p in
                            Button(p.titulo) { periodo = p }
                        }
                    } label: { chip(periodo.titulo, ativo: periodo != .mesAtual, menu: true) }

                    Menu {
                        Button("Todas as categorias") { categoria = nil }
                        ForEach(Categorias.areas) { area in
                            let lista = Categorias.todas.filter { $0.area == area.chave }
                            if lista.count == 1, let unica = lista.first {
                                Button(unica.nome) { categoria = unica.chave }
                            } else if !lista.isEmpty {
                                Menu(area.nome) {
                                    ForEach(lista) { c in Button(c.nome) { categoria = c.chave } }
                                }
                            }
                        }
                    } label: { chip(categoria.map { Categorias.info($0).nome } ?? "Categoria", ativo: categoria != nil, menu: true) }

                    Menu {
                        Button("Todas as contas") { contaID = nil }
                        ForEach(contas.filter { !$0.arquivada }, id: \.externalID) { c in
                            Button(c.nomeExibicao) { contaID = c.externalID }
                        }
                    } label: { chip(contaID.flatMap { nomeDasContas[$0] } ?? "Conta", ativo: contaID != nil, menu: true) }

                    Menu {
                        ForEach(TipoFiltro.allCases) { t in Button(t.rawValue) { tipo = t } }
                    } label: { chip(tipo.rawValue, ativo: tipo != .todos, menu: true) }

                    Button { apenasSemCategoria.toggle() } label: { chip("Sem categoria", ativo: apenasSemCategoria) }
                        .buttonStyle(.plain)
                    Button { mostrarInternos.toggle() } label: { chip("Internos", ativo: mostrarInternos) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    /// Filtro em cápsula. Ligado fica azul; os que abrem uma lista ganham uma setinha.
    private func chip(_ texto: String, ativo: Bool, menu: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(texto)
            if menu { Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)) }
        }
        .font(.subheadline)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(ativo ? Tema.acento : Tema.elevada, in: Capsule())
        .foregroundStyle(ativo ? Tema.sobreAcento : Tema.texto)
        .animation(Movimento.rapida, value: ativo)
    }
}

// MARK: - Detalhe e edição

struct DetalheLancamentoView: View {
    @Bindable var lancamento: Lancamento
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Query private var contas: [Conta]
    @Query private var regras: [Regra]
    @State private var lembrar = true
    @State private var categoriaEscolhida: String
    @State private var confirmarExclusao = false
    /// Quantos lançamentos parecidos (não corrigidos à mão) a regra alcançaria. `nil` enquanto conta.
    @State private var parecidos: Int?

    init(lancamento: Lancamento) {
        self.lancamento = lancamento
        _categoriaEscolhida = State(initialValue: lancamento.categoriaChave)
    }

    private var conta: Conta? { contas.first { $0.externalID == lancamento.contaID } }

    /// Vazio quando o texto é genérico demais ("Pix enviado", "Compra no débito"): aí não vira regra.
    private var padrao: String { Categorizador.padraoParaRegra(descricao: lancamento.descricao, estabelecimento: lancamento.estabelecimento) }

    private var textoLembrar: String {
        switch parecidos {
        case .some(let n) where n > 0: "Aplicar também a \(n) \(n == 1 ? "lançamento parecido" : "lançamentos parecidos")"
        default: "Lembrar para as próximas"
        }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Texto.primeiraMaiuscula(lancamento.data.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: "pt_BR")))))
                        .rotulo()
                    Text(lancamento.titulo).font(.title3.weight(.semibold))
                    Valor(centavos: lancamento.valorCentavos, colorido: true).numeroGrande()
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }

            Section("Categoria") {
                Picker("Categoria", selection: $categoriaEscolhida) {
                    ForEach(Categorias.areas) { area in
                        Section(area.nome) {
                            ForEach(Categorias.todas.filter { $0.area == area.chave }) { c in
                                Text(c.nome).tag(c.chave)
                            }
                        }
                    }
                }
                .onChange(of: categoriaEscolhida) { _, nova in aplicarCategoria(nova) }
                if padrao.isEmpty {
                    Text("Este texto é genérico demais para virar regra; a mudança vale só para este lançamento.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Toggle(textoLembrar, isOn: $lembrar)
                }
            }

            Section("Como conta") {
                Toggle("Transferência entre minhas contas", isOn: Binding(
                    get: { lancamento.interno },
                    set: { lancamento.interno = $0; lancamento.internoManual = true }
                ))
                Toggle("Ignorar nos relatórios", isOn: $lancamento.ignorado)
                Text("Transferências, pagamentos de fatura e aportes não contam como gasto nem como renda.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Nota") {
                TextField("Adicionar nota", text: Binding(get: { lancamento.notas ?? "" },
                                                          set: { lancamento.notas = $0.isEmpty ? nil : $0 }), axis: .vertical)
            }

            Section("Detalhes") {
                linha("Conta", conta?.nomeExibicao ?? "Sem conta")
                linha("Origem", lancamento.origem.nome)
                linha("Situação", lancamento.status == .pendente ? "Pendente" : "Efetivado")
                if let p = lancamento.parcelaAtual, let t = lancamento.totalParcelas, t > 1 { linha("Parcela", "\(p) de \(t)") }
                if let o = lancamento.descricaoOriginal, o != lancamento.descricao { linha("Descrição original", o) }
                linha("Descrição", lancamento.descricao)
                if let c = lancamento.cartaoCarteira { linha("Cartão na Carteira", c) }
            }

            if lancamento.origem == .manual || lancamento.origem == .carteira {
                Section {
                    Button("Excluir lançamento", role: .destructive) { confirmarExclusao = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Lançamento")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { fechar() } }.semCapsulaNoMac() }
        // A contagem lê todos os lançamentos; fica para depois do primeiro quadro, para a folha abrir na hora.
        .task {
            let p = padrao
            guard !p.isEmpty else { parecidos = 0; return }
            let todos = (try? contexto.fetch(FetchDescriptor<Lancamento>())) ?? []
            parecidos = Aprendizado.parecidos(p, em: todos, excluindo: lancamento).count
        }
        .confirmationDialog("Excluir este lançamento?", isPresented: $confirmarExclusao, titleVisibility: .visible) {
            Button("Excluir", role: .destructive) {
                contexto.delete(lancamento)
                try? contexto.save()
                dismiss()
            }
        }
    }

    private func linha(_ t: String, _ v: String) -> some View {
        HStack { Text(t); Spacer(); Text(v).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
    }

    private func aplicarCategoria(_ chave: String) {
        guard chave != lancamento.categoriaChave else { return }
        lancamento.categoriaChave = chave
        lancamento.categoriaManual = true
        lancamento.atualizadoEm = Date()
        let neutro = Categorias.info(chave).grupo == .neutro
        // Categoria neutra (transferência, aplicação…) sai do gasto; trocar para uma de despesa traz de volta.
        // O que você marcou à mão como "interno" fica como está.
        if !lancamento.internoManual { lancamento.interno = neutro }
        if lembrar {
            Aprendizado.lembrar(padrao: padrao, categoria: chave, contexto: contexto, regras: regras, excluindo: lancamento)
        }
        try? contexto.save()
    }

    private func fechar() {
        try? contexto.save()
        dismiss()
    }
}

struct NovoLancamentoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @Query private var contas: [Conta]
    @State private var ehReceita = false
    @State private var valorTexto = ""
    @State private var descricao = ""
    @State private var data = Date()
    @State private var contaID = ""
    @State private var categoria = "outros"

    private var valor: Int? { Dinheiro.ler(valorTexto) }
    private var valido: Bool { (valor ?? 0) > 0 && !descricao.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            Section {
                Picker("Tipo", selection: $ehReceita) {
                    Text("Gasto").tag(false)
                    Text("Receita").tag(true)
                }
                .pickerStyle(.segmented)
                TextField("Valor (ex.: 45,90)", text: $valorTexto)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("Descrição (ex.: Feira)", text: $descricao)
                DatePicker("Data", selection: $data, displayedComponents: .date)
            }
            Section {
                Picker("Conta", selection: $contaID) {
                    Text("Dinheiro / sem conta").tag("")
                    ForEach(contas.filter { !$0.arquivada }, id: \.externalID) { c in Text(c.nomeExibicao).tag(c.externalID) }
                }
                Picker("Categoria", selection: $categoria) {
                    if ehReceita {
                        ForEach(Categorias.receitas) { c in Text(c.nome).tag(c.chave) }
                    } else {
                        ForEach(Categorias.despesasPorArea, id: \.area.chave) { grupo in
                            Section(grupo.area.nome) {
                                ForEach(grupo.categorias) { c in Text(c.nome).tag(c.chave) }
                            }
                        }
                    }
                }
            } footer: {
                Text("Se a conta for um cartão ou banco conectado, este lançamento some sozinho quando o banco confirmar o mesmo valor.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Novo lançamento")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }.semCapsulaNoMac()
            ToolbarItem(placement: .confirmationAction) { Button("Salvar") { salvar() }.disabled(!valido) }.semCapsulaNoMac()
        }
        .onChange(of: ehReceita) { _, nova in categoria = nova ? "outras_receitas" : "outros" }
        .onChange(of: descricao) { _, nova in
            // Sugere a categoria enquanto digita.
            let r = Categorizador.categorizar(descricao: nova, valorCentavos: ehReceita ? 1 : -1)
            if r.origem != .padrao, Categorias.info(r.chave).ehReceita == ehReceita { categoria = r.chave }
        }
    }

    private func salvar() {
        guard let v = valor else { return }
        let dia = Datas.calendario.date(bySettingHour: 12, minute: 0, second: 0, of: data) ?? data
        let l = Lancamento(externalID: "manual-\(UUID().uuidString)", contaID: contaID, data: dia,
                           descricao: descricao.trimmingCharacters(in: .whitespaces),
                           valorCentavos: ehReceita ? v : -v, origem: .manual)
        l.categoriaChave = categoria
        l.categoriaManual = true
        l.interno = Categorias.info(categoria).grupo == .neutro
        contexto.insert(l)
        try? contexto.save()
        _ = try? Conciliador.conciliar(contexto)
        dismiss()
    }
}
