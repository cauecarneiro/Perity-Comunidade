import SwiftData
import SwiftUI
import PrumoCore

// MARK: - Dados

struct PainelFixos {
    var mes: Date
    var ehMesAtual: Bool
    var itens: [SituacaoFixo]
    var resumo: ResumoFixos
    var sugestoes: [Recorrente]
    var cartoes: Set<String>
    var contas: [Conta]

    var aPagar: [SituacaoFixo] { itens.filter { !$0.pago } }
    var pagos: [SituacaoFixo] { itens.filter(\.pago) }
    var nomeDoMes: String { mes.formatted(.dateTime.month(.wide).locale(Locale(identifier: "pt_BR"))) }

    /// O próximo a sair da conta entre os que faltam (só no mês atual).
    var proximoASair: SituacaoFixo? {
        guard ehMesAtual else { return nil }
        let hoje = Datas.inicioDoDia(Date())
        return aPagar.filter { ($0.previsaoDebito ?? .distantPast) >= hoje }
            .min { ($0.previsaoDebito ?? .distantFuture) < ($1.previsaoDebito ?? .distantFuture) }
    }

    func situacao(_ uid: String) -> SituacaoFixo? { itens.first { $0.uid == uid } }
}

/// Entrega a lista de fixos do mês, com as ações de marcar, adicionar e importar.
/// Lançamentos, contas e o que se repete no extrato já vêm calculados (ver Dados.swift): marcar um item
/// só refaz a conta dos fixos, e a caixinha anima sem tropeço.
struct ComFixos<Conteudo: View>: View {
    let mes: Date
    @Environment(\.modelContext) private var contexto
    @Environment(\.painel) private var painel
    @Environment(\.fixosDoApp) private var dados
    @ViewBuilder var conteudo: (PainelFixos, AcoesFixos) -> Conteudo

    var body: some View {
        let atual = Datas.inicioDoMes(mes) == Datas.inicioDoMes(Date())
        let contas = painel?.contas ?? []
        let itens = Fixos.situacao(fixos: dados.fixos, marcas: dados.marcas, lancamentos: painel?.lancamentos ?? [], mes: mes,
                                   contas: contas, faturas: dados.faturas, hoje: painel?.hoje ?? Date())
        let sugestoes = atual ? Fixos.sugestoes(recorrentes: painel?.recorrentes ?? [], fixos: dados.fixos) : []
        conteudo(PainelFixos(mes: mes, ehMesAtual: atual, itens: itens, resumo: Fixos.resumo(itens), sugestoes: sugestoes,
                             cartoes: Analise.idsDeCartao(contas), contas: contas.filter { !$0.arquivada }),
                 AcoesFixos(contexto: contexto, fixos: dados.fixos, marcas: dados.marcas))
    }
}

@MainActor
struct AcoesFixos {
    let contexto: ModelContext
    let fixos: [Fixo]
    let marcas: [MarcaFixo]

    func fixo(_ uid: String) -> Fixo? { fixos.first { $0.uid == uid } }

    /// Marca ou desmarca. Se o resultado for igual ao que o extrato já diz, não guarda marcação nenhuma.
    func alternar(_ s: SituacaoFixo, mes: Date) {
        let chave = Fixos.chaveMes(mes)
        let desejado = !s.pago
        for m in marcas where m.fixoUID == s.uid && m.mes == chave { contexto.delete(m) }
        if desejado != s.detectado { contexto.insert(MarcaFixo(fixoUID: s.uid, mes: chave, pago: desejado)) }
        try? contexto.save()
    }

    func adicionar(_ rec: Recorrente, ehCartao: Bool) {
        let novo = Fixos.novo(de: rec, ehCartao: ehCartao)
        novo.ordem = (fixos.map(\.ordem).max() ?? -1) + 1
        contexto.insert(novo)
        try? contexto.save()
    }

    func importar(_ rascunhos: [RascunhoFixo]) {
        var ordem = (fixos.map(\.ordem).max() ?? -1) + 1
        for r in rascunhos {
            let f = Fixo(nome: r.nome, valorCentavos: r.valorCentavos, forma: r.forma, categoriaChave: r.categoriaChave,
                         padrao: r.padrao, acumula: r.acumula)
            f.ordem = ordem
            ordem += 1
            contexto.insert(f)
        }
        try? contexto.save()
    }

    func excluir(_ fixo: Fixo) {
        for m in marcas where m.fixoUID == fixo.uid { contexto.delete(m) }
        contexto.delete(fixo)
        try? contexto.save()
    }
}

/// O que dizer embaixo do nome de um fixo: quando saiu (ou vai sair) e de onde.
func apoioDoFixo(_ s: SituacaoFixo) -> String {
    let conta = s.contaNome.map { " · \($0)" } ?? ""
    if s.acumula {
        let base = "\(Dinheiro.formatar(s.gastoCentavos)) até agora"
        return s.pago ? "\(s.forma.nome) · mês fechado" : "\(s.forma.nome) · \(base)"
    }
    if s.pago {
        if s.detectado, let d = s.dataPagamento {
            // No cartão a compra já apareceu, mas o dinheiro só sai no vencimento da fatura.
            if s.ehCartao, s.origemPrevisao == .fatura, let debito = s.previsaoDebito, debito > d {
                // Sem o nome do cartão: com ele a linha não cabe no iPhone.
                return "Cobrado \(d.diaMesCurto) · debita \(debito.diaMesCurto)"
            }
            return "Pago em \(d.diaMesCurto)\(conta)"
        }
        return "\(s.forma.nome) · marcado por você"
    }
    if s.manual && s.detectado { return "\(s.forma.nome) · você desmarcou" }
    if let d = s.previsaoDebito {
        switch s.origemPrevisao {
        case .fatura: return "Debita \(d.diaMesCurto)" + (s.contaNome.map { " · fatura \($0)" } ?? "")
        default: return "Costuma sair dia \(Datas.calendario.component(.day, from: d))\(conta)"
        }
    }
    return "\(s.forma.nome) · \(s.categoria.nome)"
}

// MARK: - Tela (iPhone)

struct FixosView: View {
    @State private var mes = Date()
    @State private var editando: Fixo?
    @State private var criando = false
    @State private var colando = false
    @State private var escolhendoNovo = false
    @Environment(\.accessibilityReduceMotion) private var reduzir
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        ComFixos(mes: mes) { p, acoes in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SeletorDeMes(mes: $mes).padding(.top, 8).entrada(0)
                    if p.itens.isEmpty {
                        vazio.entrada(1)
                    } else {
                        BlocoResumoFixos(p: p).entrada(0)
                        if !p.aPagar.isEmpty {
                            Group {
                                Fio()
                                lista("A pagar", p.aPagar, acoes)
                            }
                            .entrada(1)
                        }
                        if !p.pagos.isEmpty {
                            Group {
                                Fio()
                                lista("Pagos", p.pagos, acoes)
                            }
                            .entrada(2)
                        }
                    }
                    if !p.sugestoes.isEmpty {
                        Group {
                            Fio()
                            SecaoSugestoes(p: p, acoes: acoes).padding(.vertical, 22)
                        }
                        .entrada(3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .rolagemDeTeste()
            .background(Tema.fundo)
            .navigationTitle("Fixos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // Botão comum (e não Menu): o Menu desloca o "+" alguns pontos em relação ao de Investimentos.
                    Button { escolhendoNovo = true } label: { Image(systemName: "plus").modifier(IconeDeBarra()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Adicionar")
                }
                .semCapsula()
                BarraPrumo(secao: .fixos)
            }
            .confirmationDialog("Adicionar", isPresented: $escolhendoNovo) {
                Button("Novo gasto fixo") { criando = true }
                Button("Colar uma lista") { colando = true }
            }
            .sheet(item: $editando) { f in
                folha { EditarFixoView(fixo: f, situacao: p.situacao(f.uid), contas: p.contas, acoes: acoes, mes: mes) }
            }
            .sheet(isPresented: $criando) { folha { EditarFixoView(fixo: nil, situacao: nil, contas: p.contas, acoes: acoes, mes: mes) } }
            .sheet(isPresented: $colando) { folha { ColarFixosView(acoes: acoes) } }
        }
        .entradaDeTela(.fixos)
    }

    private func folha<V: View>(@ViewBuilder _ conteudo: () -> V) -> some View {
        NavigationStack { conteudo() }
            // A folha abre fora da aba: recebe o olho de Fixos para o histórico respeitar o que está oculto.
            .environment(\.valoresOcultos, estado.oculta(.fixos))
            #if os(macOS)
            .frame(minWidth: 460, minHeight: 520)
            #endif
    }

    private var vazio: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Suas contas do mês, com caixinha de pago.").font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Coloque aqui o que você paga todo mês. O que sair no cartão ou na conta é marcado sozinho; Pix e boleto você marca com um toque.")
                .apoio().fixedSize(horizontal: false, vertical: true)
            Button("Adicionar o primeiro") { criando = true }.buttonStyle(EstiloPrincipal()).padding(.top, 6)
            Button("Colar uma lista pronta") { colando = true }.buttonStyle(EstiloSecundario())
        }
        .padding(.vertical, 28)
    }

    private func lista(_ titulo: String, _ itens: [SituacaoFixo], _ acoes: AcoesFixos) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CabecalhoSecao(titulo: titulo) {
                Valor(centavos: itens.reduce(0) { $0 + $1.valorCentavos })
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Tema.terciario)
            }
            .padding(.bottom, 6)
            ForEach(itens) { s in
                LinhaFixo(s: s, automatico: acoes.fixo(s.uid)?.automatico ?? false,
                          aoMarcar: { withAnimation(reduzir ? nil : Movimento.suave) { acoes.alternar(s, mes: mes) } },
                          aoAbrir: { editando = acoes.fixo(s.uid) })
            }
        }
        .padding(.vertical, 22)
    }
}

/// "‹ outubro de 2026 ›": troca o mês da lista. Não vai além do mês atual.
struct SeletorDeMes: View {
    @Binding var mes: Date

    var body: some View {
        let atual = Datas.inicioDoMes(mes) >= Datas.inicioDoMes(Date())
        HStack(spacing: 4) {
            botao("chevron.left", "Mês anterior") { mes = Datas.somar(meses: -1, a: mes) }
            Text(mes.mesAno).rotulo().frame(minWidth: 150)
            botao("chevron.right", "Mês seguinte") { mes = Datas.somar(meses: 1, a: mes) }
                .disabled(atual).opacity(atual ? 0.3 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, -12)
    }

    private func botao(_ icone: String, _ nome: String, _ acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Image(systemName: icone).font(.system(size: 13, weight: .semibold)).foregroundStyle(Tema.secundario)
                .frame(width: 40, height: 40).contentShape(Rectangle())
        }
        .buttonStyle(.toque)
        .accessibilityLabel(nome)
    }
}

struct BlocoResumoFixos: View {
    let p: PainelFixos

    var body: some View {
        let tudoPago = p.resumo.faltaCentavos == 0
        BlocoMacro(rotulo: tudoPago ? "Tudo pago em \(p.nomeDoMes)" : "Falta pagar em \(p.nomeDoMes)", seta: false) {
            NumeroHeroi(centavos: tudoPago ? p.resumo.totalCentavos : p.resumo.faltaCentavos, cor: tudoPago ? Tema.acento : Tema.texto)
            BarraSegmentos(total: p.resumo.quantidade, feitos: p.resumo.pagos).padding(.vertical, 2)
            TextoPrivado("\(p.resumo.pagos) de \(p.resumo.quantidade) pagos · total do mês \(Dinheiro.formatar(p.resumo.totalCentavos))").apoio()
            if let s = p.proximoASair, let d = s.previsaoDebito {
                Text("Próximo a sair: \(s.nome), \(d.diaMesCurto)").apoio()
            }
        }
    }
}

/// Uma linha da lista: a caixinha marca como pago; o resto da linha abre a edição.
struct LinhaFixo: View {
    let s: SituacaoFixo
    /// Entrou na lista pela varredura do extrato, não pela sua mão.
    var automatico = false
    let aoMarcar: () -> Void
    let aoAbrir: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Button(action: aoMarcar) {
                Caixinha(marcada: s.pago).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(s.pago ? "Desmarcar \(s.nome)" : "Marcar \(s.nome) como pago")
            .sensoryFeedback(trigger: s.pago) { _, novo in novo ? .success : .selection }

            Button(action: aoAbrir) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(s.nome).font(.body).lineLimit(1)
                                .foregroundStyle(s.pago ? Tema.secundario : Tema.texto)
                            if let a = s.parcelaAtual, let t = s.totalParcelas { Selo(texto: "\(a)/\(t)") }
                            if automatico {
                                Text("detectado").font(.system(size: 10, design: .monospaced)).foregroundStyle(Tema.terciario)
                            }
                        }
                        TextoPrivado(apoioDoFixo(s)).font(.caption).foregroundStyle(Tema.secundario).lineLimit(1)
                        if s.acumula, !s.pago, s.valorCentavos > 0 {
                            BarraProgresso(valor: Double(s.gastoCentavos) / Double(s.valorCentavos),
                                           cor: s.gastoCentavos > s.valorCentavos ? Tema.ambar : Tema.acento, altura: 3)
                                .frame(width: 170)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Valor(centavos: s.valorCentavos).font(.numero(16, .medium))
                        .foregroundStyle(s.pago ? Tema.secundario : Tema.texto)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.toque)
            .accessibilityHint("Editar")
        }
        .padding(.leading, -9)
    }
}

/// Gastos que se repetem no extrato e ainda não estão na lista.
struct SecaoSugestoes: View {
    let p: PainelFixos
    let acoes: AcoesFixos

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CabecalhoSecao(titulo: "Aparecem todo mês no extrato")
            ForEach(p.sugestoes.prefix(6)) { r in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.nome).font(.body).lineLimit(1)
                        TextoPrivado("\(Dinheiro.formatar(r.valorCentavos)) · \(r.categoria.nome)").font(.caption).foregroundStyle(Tema.secundario).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button("Adicionar") { withAnimation(Movimento.suave) { acoes.adicionar(r, ehCartao: p.cartoes.contains(r.contaID)) } }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Tema.acento)
                        .buttonStyle(.toque)
                }
            }
        }
    }
}

// MARK: - Editar

struct EditarFixoView: View {
    let fixo: Fixo?
    /// Como está no mês aberto (nil quando é um fixo novo).
    let situacao: SituacaoFixo?
    let contas: [Conta]
    let acoes: AcoesFixos
    /// O mês aberto na lista (o histórico termina nele).
    var mes = Date()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @State private var nome = ""
    @State private var valor = ""
    @State private var forma: FormaPagamento = .cartao
    @State private var categoria = "outros"
    @State private var acumula = false
    @State private var padrao = ""
    @State private var contaID = ""
    @State private var diaTipico = 0
    @State private var confirmarExclusao = false

    var body: some View {
        Form {
            if let s = situacao {
                Section("Neste mês") {
                    LinhaValor(titulo: estadoDoMes(s), apoio: apoioDoFixo(s),
                               centavos: s.gastoCentavos > 0 ? s.gastoCentavos : s.valorCentavos,
                               corApoio: s.pago ? Tema.acento : Tema.secundario)
                    if let filtro = filtroDoExtrato(s) {
                        NavigationLink { LancamentosView(filtroInicial: filtro) } label: { RotuloLink(texto: "Ver no extrato") }
                    }
                }
                Section("Histórico") { HistoricoFixo(s: s, mes: mes) }
            }
            Section {
                TextField("Nome (ex.: Academia)", text: $nome)
                TextField("Valor por mês (ex.: 299,00)", text: $valor)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Picker("Como você paga", selection: $forma) {
                    ForEach(FormaPagamento.allCases, id: \.self) { Text($0.nome).tag($0) }
                }
                Picker("Categoria", selection: $categoria) {
                    ForEach(Categorias.despesasPorArea, id: \.area.chave) { grupo in
                        Section(grupo.area.nome) {
                            ForEach(grupo.categorias) { Text($0.nome).tag($0.chave) }
                        }
                    }
                }
            }
            Section {
                Picker("De onde sai", selection: $contaID) {
                    Text("Nenhuma").tag("")
                    ForEach(contas, id: \.externalID) { Text($0.nomeExibicao).tag($0.externalID) }
                }
                Picker("Dia em que costuma sair", selection: $diaTipico) {
                    Text("Não sei").tag(0)
                    ForEach(1...31, id: \.self) { Text("Dia \($0)").tag($0) }
                }
            } footer: {
                Text("Com a conta e o dia, o Perity mostra quando o dinheiro sai de verdade (no cartão, o vencimento da fatura). A varredura do extrato preenche sozinha quando consegue.")
            }
            Section {
                Toggle("São vários gastos no mês", isOn: $acumula)
            } footer: {
                Text("Ligue para mercado, gasolina e parecidos: o Perity soma o que saiu no mês e mostra quanto falta para o valor combinado.")
            }
            Section {
                TextField(acumula ? "Vazio = soma a categoria toda" : "Vazio = usa o nome", text: $padrao)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                NavigationLink("Escolher um lançamento do extrato") {
                    EscolherLancamentoView { texto, centavos in
                        padrao = texto
                        if !acumula, (Dinheiro.ler(valor) ?? 0) == 0 {
                            valor = String(format: "%.2f", Dinheiro.reais(centavos)).replacingOccurrences(of: ".", with: ",")
                        }
                    }
                }
            } header: {
                Text("Como aparece no extrato")
            } footer: {
                Text("É por aqui que o Perity marca como pago sozinho quando a cobrança chega. Para mais de um nome, separe por vírgula (ex.: claude, anthropic).")
            }
            if fixo != nil {
                Section {
                    Button("Excluir da lista", role: .destructive) { confirmarExclusao = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle(fixo == nil ? "Novo gasto fixo" : "Editar")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .formStyle(.grouped)
        #endif
        .onAppear {
            guard let f = fixo, nome.isEmpty else { return }
            nome = f.nome
            valor = String(format: "%.2f", Dinheiro.reais(f.valorCentavos)).replacingOccurrences(of: ".", with: ",")
            forma = f.forma
            categoria = f.categoriaChave
            acumula = f.acumula
            padrao = f.padrao
            contaID = f.contaID ?? situacao?.contaID ?? ""
            diaTipico = f.diaTipico ?? situacao?.diaTipico ?? 0
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }.semCapsulaNoMac()
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { salvar() }
                    .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty || (Dinheiro.ler(valor) ?? 0) <= 0)
            }.semCapsulaNoMac()
        }
        .confirmationDialog("Excluir \(nome) da lista de fixos?", isPresented: $confirmarExclusao, titleVisibility: .visible) {
            Button("Excluir", role: .destructive) {
                if let f = fixo { acoes.excluir(f) }
                dismiss()
            }
        }
    }

    private func salvar() {
        let f = fixo ?? Fixo(nome: nome, valorCentavos: 0)
        f.nome = nome.trimmingCharacters(in: .whitespaces)
        f.valorCentavos = Dinheiro.ler(valor) ?? 0
        f.forma = forma
        f.categoriaChave = categoria
        f.acumula = acumula
        f.padrao = padrao.trimmingCharacters(in: .whitespaces)
        f.contaID = contaID.isEmpty ? nil : contaID
        f.diaTipico = diaTipico == 0 ? nil : diaTipico
        if fixo == nil {
            f.ordem = (acoes.fixos.map(\.ordem).max() ?? -1) + 1
            contexto.insert(f)
        }
        try? contexto.save()
        dismiss()
    }

    private func estadoDoMes(_ s: SituacaoFixo) -> String {
        if s.acumula { return s.pago ? "Mês fechado" : "Somando o mês" }
        if s.pago { return s.detectado ? "Pago" : "Marcado como pago" }
        return s.previsaoDebito == nil ? "A pagar" : "A pagar · previsto"
    }

    /// As cobranças deste fixo (12 meses); sem nenhuma, a busca pelo texto do extrato.
    private func filtroDoExtrato(_ s: SituacaoFixo) -> FiltroLancamentos? {
        var ids = Set(s.historico.map(\.externalID))
        ids.formUnion(s.lancamentoIDs)
        if !ids.isEmpty { return FiltroLancamentos(titulo: s.nome, externalIDs: ids) }
        let texto = padrao.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let busca = texto.isEmpty ? nome : texto
        return busca.isEmpty ? nil : FiltroLancamentos(titulo: s.nome, busca: busca)
    }
}

/// Os últimos 12 meses de um fixo: em que dia saiu e quanto. Mês sem cobrança fica com um traço.
struct HistoricoFixo: View {
    let s: SituacaoFixo
    let mes: Date

    var body: some View {
        let fim = Datas.inicioDoMes(mes)
        let meses = (0..<12).map { Datas.somar(meses: -$0, a: fim) }
        let porMes = Dictionary(s.historico.map { ($0.mes, $0) }, uniquingKeysWith: { a, _ in a })
        ForEach(meses, id: \.self) { mes in
            HStack(alignment: .firstTextBaseline) {
                Text(mes.mesAno).font(.subheadline)
                Spacer(minLength: 8)
                if let c = porMes[Fixos.chaveMes(mes)] {
                    Text("dia \(Datas.calendario.component(.day, from: c.data))").font(.caption).foregroundStyle(Tema.secundario)
                    Valor(centavos: c.valorCentavos).font(.numero(15, .medium)).frame(minWidth: 96, alignment: .trailing)
                } else {
                    Text("—").font(.numero(15, .medium)).foregroundStyle(Tema.terciario).frame(minWidth: 96, alignment: .trailing)
                }
            }
        }
    }
}

/// Lista as saídas recentes para você apontar "é esta cobrança aqui".
struct EscolherLancamentoView: View {
    let aoEscolher: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Lancamento.data, order: .reverse)]) private var todos: [Lancamento]
    @State private var busca = ""

    var body: some View {
        let desde = Datas.somar(dias: -75, a: Date())
        let q = Texto.normalizar(busca)
        let itens = todos.filter {
            $0.valorCentavos < 0 && $0.data >= desde && !$0.ignorado && $0.conciliadoComID == nil
                && (q.isEmpty || Texto.normalizar($0.descricao + " " + ($0.estabelecimento ?? "")).contains(q))
        }
        List {
            if itens.isEmpty {
                Text("Nenhuma saída encontrada nos últimos 75 dias.").foregroundStyle(Tema.secundario)
            }
            ForEach(itens.prefix(200)) { l in
                Button {
                    let padrao = Categorizador.padraoParaRegra(descricao: l.descricao, estabelecimento: l.estabelecimento)
                    aoEscolher(padrao.isEmpty ? Texto.normalizar(l.titulo) : padrao, l.valorAbsoluto)
                    dismiss()
                } label: {
                    LinhaLancamento(lancamento: l, mostrarData: true)
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .searchable(text: $busca, prompt: "Buscar no extrato")
        .navigationTitle("Qual é a cobrança?")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Colar lista

struct ColarFixosView: View {
    let acoes: AcoesFixos
    @Environment(\.dismiss) private var dismiss
    @State private var texto = ""

    var body: some View {
        let itens = Fixos.ler(texto)
        Form {
            Section {
                TextEditor(text: $texto)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 220)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            } header: {
                Text("Uma linha por gasto")
            } footer: {
                Text("Formato: Nome; valor; forma; categoria. Exemplos:\nAcademia; 299,00; cartão; academia\nMercado; 1.800,00; cartão; mercado; soma\nGasolina; 800,00; cartão; gasolina; soma\nClaude; 500,00; cartão; apps e IA; extrato=claude, anthropic")
            }
            if !itens.isEmpty {
                Section("Vou adicionar") {
                    ForEach(Array(itens.enumerated()), id: \.offset) { _, r in
                        LinhaValor(titulo: r.nome,
                                   apoio: "\(r.forma.nome) · \(Categorias.info(r.categoriaChave).nome)\(r.acumula ? " · soma do mês" : "")",
                                   centavos: r.valorCentavos)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Colar lista")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .formStyle(.grouped)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }.semCapsulaNoMac()
            ToolbarItem(placement: .confirmationAction) {
                Button(itens.isEmpty ? "Adicionar" : "Adicionar \(itens.count)") {
                    acoes.importar(itens)
                    dismiss()
                }
                .disabled(itens.isEmpty)
            }.semCapsulaNoMac()
        }
    }
}
