import SwiftData
import SwiftUI
import PrumoCore

func textoDoDia(_ d: Date, hoje: Date = Date()) -> String {
    let n = Datas.dias(de: hoje, ate: d)
    if n <= 0 { return "hoje" }
    if n == 1 { return "amanhã" }
    if n <= 7 { return "em \(n) dias" }
    return "em \(d.diaMesCurto)"
}

// MARK: - Início (iPhone)

/// O macro: quatro números e três listas curtas. Cada número abre o seu detalhe.
struct InicioView: View {
    @Environment(EstadoApp.self) private var estado

    var body: some View {
        ComPainel { p in
            ScrollViewReader { rolagem in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NavigationLink(value: Destino.contas) { BlocoSaldo(p: p) }
                        .buttonStyle(.toque).origemZoom("contas").entrada(0)
                    Group {
                        Fio()
                        NavigationLink(value: Destino.cartoes) { BlocoFaturas(p: p) }
                            .buttonStyle(.toque).origemZoom("cartoes")
                    }
                    .entrada(1)
                    Group {
                        Fio()
                        NavigationLink(value: Destino.analise) { BlocoGastos(p: p) }
                            .buttonStyle(.toque).origemZoom("analise")
                    }
                    .entrada(2)
                    Group {
                        Fio()
                        Button { estado.ir(.fixos) } label: { BlocoFixos(p: p) }
                            .buttonStyle(.toque)
                    }
                    .entrada(3)
                    if !p.vencimentos.isEmpty {
                        Group {
                            Fio()
                            SecaoVencimentos(p: p, limite: 3).padding(.vertical, 22)
                        }
                        .entrada(4)
                    }
                    Group {
                        Fio()
                        SecaoRecentes(p: p, limite: 5).padding(.vertical, 22)
                    }
                    .entrada(5)
                    // O aviso fica por último: os números e os lançamentos vêm antes dele.
                    if let aviso = p.avisos.first {
                        Group {
                            Fio()
                            NavigationLink(value: Destino.avisos) { BlocoAviso(aviso: aviso, total: p.avisos.count) }
                                .buttonStyle(.toque)
                        }
                        .entrada(6)
                    }
                    IndicadorAtualizacao().padding(.top, 4).id("fim").entrada(6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            #if DEBUG
            .onAppear {
                // Fotos das telas: `-prumo-ancora fim` rola até o fim do Início.
                guard UserDefaults.standard.string(forKey: "prumo-ancora") == "fim" else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { rolagem.scrollTo("fim", anchor: .bottom) }
            }
            #endif
            }
            .background(Tema.fundo)
            .navigationTitle("Início")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                // O topo fica limpo: sem título e sem marca, só os dois botões.
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
                BarraPrumo()
            }
            .refreshable { await estado.atualizar() }
        }
        .entradaDeTela(.inicio)
    }
}

/// O nome do app, pequeno, com o ponto de limão.
struct Marca: View {
    var tamanho: CGFloat = 17

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: tamanho * 0.12) {
            Text("perity").font(.system(size: tamanho, weight: .semibold)).tracking(-tamanho * 0.02).foregroundStyle(Tema.texto)
            Circle().fill(Tema.acento).frame(width: tamanho * 0.3, height: tamanho * 0.3)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Perity")
    }
}

// MARK: - Blocos do macro

/// A moldura de um bloco do Início: etiqueta em cima, setinha no canto, conteúdo embaixo.
struct BlocoMacro<Corpo: View>: View {
    let rotulo: String
    var seta = true
    @ViewBuilder var corpo: () -> Corpo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(rotulo).rotulo()
                Spacer(minLength: 8)
                if seta { Seta() }
            }
            corpo()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 22)
        .contentShape(Rectangle())
    }
}

struct BlocoSaldo: View {
    let p: PainelInicio
    var seta = true

    var body: some View {
        BlocoMacro(rotulo: "Saldo em conta", seta: seta) {
            NumeroHeroi(centavos: p.saldoCentavos)
            Text(resumo).apoio()
        }
    }

    private var resumo: String {
        let c = p.quantasContas, b = p.bancos.count
        if c == 0 { return "Nenhuma conta conectada" }
        return "\(c) \(c == 1 ? "conta" : "contas") em \(b) \(b == 1 ? "banco" : "bancos")"
    }
}

struct BlocoFaturas: View {
    let p: PainelInicio
    var seta = true

    var body: some View {
        BlocoMacro(rotulo: "Faturas dos cartões", seta: seta) {
            NumeroHeroi(centavos: p.faturasCentavos, tamanho: 34)
            if p.cartoes.isEmpty {
                Text("Nenhum cartão conectado").apoio()
            } else {
                TextoPrivado(resumo).apoio()
            }
        }
    }

    private var resumo: String {
        var partes: [String] = []
        if p.limiteTotalCentavos > 0 { partes.append("Limite livre \(Dinheiro.formatarCompacto(p.limiteLivreCentavos))") }
        if let v = p.proximoVencimentoFatura { partes.append("próxima vence \(textoDoDia(v, hoje: p.hoje))") }
        if partes.isEmpty { partes.append("\(p.cartoes.count) \(p.cartoes.count == 1 ? "cartão" : "cartões")") }
        return partes.joined(separator: " · ")
    }
}

struct BlocoGastos: View {
    let p: PainelInicio
    var seta = true

    var body: some View {
        BlocoMacro(rotulo: "Gastos de \(p.nomeDoMes)", seta: seta) {
            NumeroHeroi(centavos: p.mes.despesasCentavos, tamanho: 34)
            if p.previsao.projetadoCentavos > 0 {
                BarraProgresso(valor: min(1, Double(p.previsao.gastoAteHojeCentavos) / Double(max(p.previsao.projetadoCentavos, 1))), altura: 4)
                    .padding(.vertical, 2)
                TextoPrivado("No ritmo atual, fecha o mês em \(Dinheiro.formatar(p.previsao.projetadoCentavos))").apoio()
            } else {
                Text("Sem gastos neste mês ainda").apoio()
            }
        }
    }
}

struct BlocoFixos: View {
    let p: PainelInicio
    var seta = true

    var body: some View {
        BlocoMacro(rotulo: "Fixos de \(p.nomeDoMes)", seta: seta) {
            if p.fixos.quantidade == 0 {
                Text("Monte a lista das contas do mês").font(.title3.weight(.semibold))
                Text("Aluguel, academia, assinaturas: marque o que já pagou.").apoio()
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Falta").font(.system(size: 15, weight: .medium)).foregroundStyle(Tema.secundario)
                    NumeroHeroi(centavos: p.fixos.faltaCentavos, tamanho: 34,
                                cor: p.fixos.faltaCentavos == 0 ? Tema.acento : Tema.texto)
                }
                BarraSegmentos(total: p.fixos.quantidade, feitos: p.fixos.pagos).padding(.vertical, 2)
                Text("\(p.fixos.pagos) de \(p.fixos.quantidade) pagos").apoio()
            }
        }
    }
}

struct BlocoAviso: View {
    let aviso: Insight
    let total: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            LinhaAviso(aviso: aviso)
            if total > 1 { Text("+\(total - 1)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Tema.secundario) }
            Seta()
        }
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }
}

struct LinhaAviso: View {
    let aviso: Insight

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(Tema.cor(aviso.severidade)).frame(width: 7, height: 7)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                TextoPrivado(aviso.titulo).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                TextoPrivado(aviso.texto).font(.caption).foregroundStyle(Tema.secundario).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.leading)
    }
}

// MARK: - Listas curtas

struct SecaoVencimentos: View {
    let p: PainelInicio
    var limite = 3

    var body: some View {
        let itens = Array(p.vencimentos.prefix(limite))
        VStack(alignment: .leading, spacing: 14) {
            CabecalhoSecao(titulo: "Vence em breve") {
                if p.vencimentos.count > itens.count {
                    Text("+\(p.vencimentos.count - itens.count) em 14 dias").font(.caption).foregroundStyle(Tema.terciario)
                }
            }
            ForEach(itens) { v in
                let dias = Datas.dias(de: p.hoje, ate: v.data)
                LinhaValor(titulo: v.titulo,
                           apoio: Texto.primeiraMaiuscula(textoDoDia(v.data, hoje: p.hoje)) + (dias > 7 ? "" : " · \(v.data.diaMesCurto)") + (v.estimado ? " · estimado" : ""),
                           centavos: v.valorCentavos,
                           corApoio: dias <= 1 ? Tema.ambar : Tema.secundario)
            }
        }
    }
}

struct SecaoRecentes: View {
    let p: PainelInicio
    var limite = 5

    var body: some View {
        let itens = Array(p.recentes.prefix(limite))
        VStack(alignment: .leading, spacing: 14) {
            CabecalhoSecao(titulo: "Últimos lançamentos") {
                NavigationLink(value: Destino.lancamentos(FiltroLancamentos())) { RotuloLink(texto: "Ver todos") }
                    .buttonStyle(.toque)
            }
            if itens.isEmpty {
                EstadoVazio(titulo: "Nada por aqui ainda", texto: "Os lançamentos aparecem assim que o banco atualizar.")
            } else {
                ForEach(itens) { l in LinhaLancamento(lancamento: l, mostrarData: true) }
            }
        }
    }
}

// MARK: - O micro de contas e cartões (usado nas telas de detalhe e no painel do Mac)

struct ListaBancos: View {
    let p: PainelInicio

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(p.bancos) { banco in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(banco.nome).rotulo()
                        Spacer(minLength: 8)
                        if p.saldoCentavos > 0, p.bancos.count > 1 {
                            Text("\(Int((Double(max(banco.totalCentavos, 0)) / Double(p.saldoCentavos) * 100).rounded()))%")
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Tema.terciario)
                        }
                    }
                    if p.saldoCentavos > 0, p.bancos.count > 1 {
                        BarraProgresso(valor: Double(max(banco.totalCentavos, 0)) / Double(p.saldoCentavos), altura: 3)
                    }
                    ForEach(banco.contas, id: \.externalID) { c in
                        NavigationLink(value: Destino.conta(c.externalID)) {
                            LinhaValor(titulo: c.nomeExibicao,
                                       apoio: c.contaNoPatrimonio ? (c.nomeExibicao.lowercased() == c.tipo.nome.lowercased() ? nil : c.tipo.nome) : "Fora da soma",
                                       centavos: c.saldoCentavos, seta: true)
                        }
                        .buttonStyle(.toque)
                    }
                }
            }
        }
    }
}

struct ListaCartoes: View {
    let p: PainelInicio

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(p.cartoes, id: \.externalID) { c in
                NavigationLink(value: Destino.conta(c.externalID)) { cartao(c) }.buttonStyle(.toque)
            }
        }
    }

    private func cartao(_ c: Conta) -> some View {
        let detalhe = [c.bandeira, c.final4.map { "final \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 10) {
            LinhaValor(titulo: c.nomeExibicao, apoio: detalhe.isEmpty ? nil : detalhe, centavos: max(c.saldoCentavos, 0), seta: true)
            if let uso = c.usoDoLimite {
                BarraProgresso(valor: uso, cor: uso > 0.8 ? Tema.vermelho : Tema.acento, altura: 3)
            }
            HStack(spacing: 4) {
                if c.limiteCentavos != nil {
                    Text("Livre")
                    Valor(centavos: c.disponivelCentavos ?? 0).foregroundStyle(Tema.texto)
                    Text("de")
                    Valor(centavos: c.limiteCentavos ?? 0, compacto: true)
                }
                Spacer(minLength: 8)
                if let v = c.vencimentoFatura {
                    Text("Vence \(textoDoDia(v, hoje: p.hoje))")
                        .foregroundStyle(Datas.dias(de: p.hoje, ate: v) <= 3 ? Tema.ambar : Tema.secundario)
                } else if let f = c.fechamentoFatura {
                    Text("Fecha \(textoDoDia(f, hoje: p.hoje))")
                }
            }
            .font(.caption).foregroundStyle(Tema.secundario).lineLimit(1)
        }
    }
}

// MARK: - O micro do mês

/// As frases objetivas sobre o mês: o que se destaca, com o número que prova.
struct SecaoDestaques: View {
    @Environment(EstadoApp.self) private var estado
    let p: PainelInicio
    var limite: Int?

    var body: some View {
        let itens = limite.map { Array(p.destaques.prefix($0)) } ?? p.destaques
        VStack(alignment: .leading, spacing: 18) {
            CabecalhoSecao(titulo: "Destaques de \(p.nomeDoMes)")
            ForEach(itens) { d in
                if let chave = d.categoriaChave {
                    let filtro = FiltroLancamentos(categoria: chave, mes: p.hoje, titulo: Categorias.info(chave).nome)
                    #if os(macOS)
                    Button { estado.abrirLancamentos(filtro) } label: { LinhaDestaque(destaque: d, seta: true) }
                        .buttonStyle(.toque)
                    #else
                    NavigationLink(value: Destino.lancamentos(filtro)) { LinhaDestaque(destaque: d, seta: true) }
                        .buttonStyle(.toque)
                    #endif
                } else {
                    LinhaDestaque(destaque: d)
                }
            }
        }
    }
}

struct LinhaDestaque: View {
    let destaque: Destaque
    var seta = false

    private var cor: Color {
        switch destaque.tom {
        case .bom: Tema.acento
        case .atencao: Tema.ambar
        case .neutro: Tema.terciario
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Capsule().fill(cor).frame(width: 3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(destaque.rotulo).rotulo()
                TextoPrivado(destaque.titulo).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                TextoPrivado(destaque.texto).font(.caption).foregroundStyle(Tema.secundario).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if seta { Seta() }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
    }
}

enum ModoCategorias: Hashable { case detalhe, areas }

/// Para onde foi o dinheiro: cada categoria em separado (gasolina, delivery, mercado…) ou juntas por área.
struct SecaoCategorias: View {
    let p: PainelInicio
    var limite: Int?
    @State private var modo: ModoCategorias = .detalhe

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CabecalhoSecao(titulo: "Para onde foi") {
                if !p.mes.porCategoria.isEmpty {
                    Text("\(p.mes.porCategoria.count) categorias").font(.system(size: 11, design: .monospaced)).foregroundStyle(Tema.terciario)
                }
            }
            if p.mes.porCategoria.isEmpty {
                EstadoVazio(titulo: "Sem gastos neste mês", texto: "Quando entrarem lançamentos, eles aparecem aqui.")
            } else {
                Seletor(opcoes: [OpcaoSeletor(valor: ModoCategorias.detalhe, titulo: "Detalhado"),
                                 OpcaoSeletor(valor: ModoCategorias.areas, titulo: "Por área")],
                        selecionado: $modo)
                switch modo {
                case .detalhe: ListaCategorias(gastos: p.mes.porCategoria, limite: limite ?? 100, mes: p.hoje)
                case .areas: ListaAreas(areas: p.areas, mes: p.hoje)
                }
            }
        }
    }
}

struct SecaoRitmo: View {
    let p: PainelInicio
    var altura: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CabecalhoSecao(titulo: "Ritmo do mês")
            if let c = p.comparacaoRitmo {
                let pct = Int((abs(c) * 100).rounded())
                Text(pct == 0 ? "No mesmo ritmo do mês passado." : "\(pct)% \(c <= 0 ? "abaixo" : "acima") do mês passado até hoje.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(pct == 0 ? Tema.texto : (c <= 0 ? Tema.acento : Tema.ambar))
            }
            RitmoDoMes(pontos: p.ritmo).frame(height: altura)
            LegendaDupla(foco: "Este mês", comparacao: "Mês passado")
        }
    }
}

struct SecaoFluxo: View {
    let p: PainelInicio
    var altura: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CabecalhoSecao(titulo: "Entrou e saiu · 6 meses")
            TextoPrivado("Em \(p.nomeDoMes) entrou \(Dinheiro.formatar(p.mes.receitasCentavos)) e \(p.mes.saldoCentavos >= 0 ? "sobrou" : "faltou") \(Dinheiro.formatar(abs(p.mes.saldoCentavos))).")
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            BarrasMensais(pontos: p.serie).frame(height: altura)
            LegendaDupla(foco: "Saiu", comparacao: "Entrou")
        }
    }
}

// MARK: - Telas de detalhe (iPhone)

/// Micro do saldo: em quais bancos o dinheiro está.
struct ContasDetalheView: View {
    @State private var adicionando = false

    var body: some View {
        ComPainel { p in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BlocoSaldo(p: p, seta: false).entrada(0)
                    Group {
                        Fio()
                        if p.bancos.isEmpty {
                            EstadoVazio(titulo: "Nenhuma conta ainda", texto: "Conecte seus bancos em Ajustes ou adicione uma conta manual no +.")
                                .padding(.vertical, 22)
                        } else {
                            ListaBancos(p: p).padding(.vertical, 24)
                        }
                    }
                    .entrada(1)
                    if !p.conexoes.isEmpty {
                        Group {
                            Fio()
                            SecaoConexoes(p: p).padding(.vertical, 22)
                        }
                        .entrada(2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .rolagemDeTeste()
            .background(Tema.fundo)
            .navigationTitle("Contas")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adicionando = true } label: { Image(systemName: "plus").modifier(IconeDeBarra()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Adicionar conta")
                }
                .semCapsula()
            }
            .sheet(isPresented: $adicionando) {
                NavigationStack { NovaContaView() }
                    #if os(macOS)
                    .frame(minWidth: 420, minHeight: 360)
                    #endif
            }
        }
        .entradaDeTela()
        .destinoZoom("contas")
    }
}

/// Micro das faturas: quanto é de cada cartão e quanto de limite ainda há.
struct CartoesDetalheView: View {
    var body: some View {
        ComPainel { p in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BlocoMacro(rotulo: "Faturas dos cartões", seta: false) {
                        NumeroHeroi(centavos: p.faturasCentavos)
                        if p.limiteTotalCentavos > 0 {
                            BarraProgresso(valor: 1 - Double(p.limiteLivreCentavos) / Double(p.limiteTotalCentavos), altura: 4)
                                .padding(.vertical, 2)
                            TextoPrivado("Limite livre \(Dinheiro.formatar(p.limiteLivreCentavos)) de \(Dinheiro.formatar(p.limiteTotalCentavos))").apoio()
                        }
                    }
                    .entrada(0)
                    Group {
                        Fio()
                        if p.cartoes.isEmpty {
                            EstadoVazio(titulo: "Nenhum cartão ainda", texto: "Os cartões aparecem quando o banco deles estiver conectado.")
                                .padding(.vertical, 22)
                        } else {
                            ListaCartoes(p: p).padding(.vertical, 24)
                        }
                    }
                    .entrada(1)
                    if !p.emprestimos.isEmpty {
                        Group {
                            Fio()
                            SecaoEmprestimos(p: p).padding(.vertical, 22)
                        }
                        .entrada(2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .rolagemDeTeste()
            .background(Tema.fundo)
            .navigationTitle("Cartões")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .entradaDeTela()
        .destinoZoom("cartoes")
    }
}

struct SecaoEmprestimos: View {
    let p: PainelInicio

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CabecalhoSecao(titulo: "Empréstimos e financiamentos")
            ForEach(p.emprestimos, id: \.externalID) { e in
                VStack(alignment: .leading, spacing: 8) {
                    LinhaValor(titulo: e.nome, apoio: apoio(e), centavos: e.saldoDevedorCentavos ?? 0)
                    if e.contratadoCentavos > 0, let s = e.saldoDevedorCentavos {
                        BarraProgresso(valor: 1 - Double(s) / Double(e.contratadoCentavos), altura: 3)
                    }
                }
            }
        }
    }

    private func apoio(_ e: Emprestimo) -> String? {
        var partes: [String] = []
        if let r = e.parcelasRestantes { partes.append("\(r) parcelas restantes") }
        if let v = e.proximoVencimento { partes.append("vence \(v.diaMesCurto)") }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }
}

struct SecaoConexoes: View {
    @Environment(EstadoApp.self) private var estado
    let p: PainelInicio

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CabecalhoSecao(titulo: "Conexões com bancos") {
                if estado.buscaBancos, estado.temCredenciais, !estado.modoDemo {
                    Button { Task { await estado.atualizar() } } label: { RotuloLink(texto: "Buscar agora") }
                        .buttonStyle(.toque)
                        .disabled(estado.atualizacao == .atualizando)
                }
            }
            ForEach(p.conexoes.sorted { $0.ordem < $1.ordem }, id: \.itemID) { c in
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.nome.isEmpty ? "Banco" : c.nome).font(.body)
                    Text(situacao(c)).font(.caption).foregroundStyle(c.precisaAtencao ? Tema.vermelho : Tema.secundario)
                }
            }
        }
    }

    private func situacao(_ c: Conexao) -> String {
        if c.demo { return "Exemplo · atualizado \(textoRelativo(c.ultimaAtualizacao ?? Date()))" }
        if c.precisaAtencao { return "Precisa reconectar no Meu Pluggy" }
        var partes: [String] = []
        if let u = c.ultimaAtualizacao { partes.append("Atualizado \(textoRelativo(u))") }
        if let prox = c.proximaAtualizacao, prox > Date() { partes.append("próxima \(textoRelativo(prox))") }
        return partes.isEmpty ? "Aguardando primeira atualização" : partes.joined(separator: " · ")
    }
}

/// Micro dos gastos do mês: o que se destaca, para onde foi (categoria por categoria), em que ritmo,
/// e como se compara aos meses anteriores.
struct AnaliseView: View {
    var body: some View {
        ComPainel { p in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BlocoGastos(p: p, seta: false).entrada(0)
                    // Primeiro para onde o dinheiro foi, categoria por categoria; os destaques vêm depois.
                    Group {
                        Fio()
                        SecaoCategorias(p: p).padding(.vertical, 24)
                    }
                    .entrada(1)
                    if !p.destaques.isEmpty {
                        Group {
                            Fio()
                            SecaoDestaques(p: p).padding(.vertical, 24)
                        }
                        .entrada(2)
                    }
                    Group {
                        Fio()
                        SecaoRitmo(p: p).padding(.vertical, 24)
                    }
                    .entrada(3)
                    Group {
                        Fio()
                        SecaoFluxo(p: p).padding(.vertical, 24)
                    }
                    .entrada(4)
                    if !p.avisos.isEmpty {
                        Group {
                            Fio()
                            VStack(alignment: .leading, spacing: 16) {
                                CabecalhoSecao(titulo: "Para ficar de olho")
                                ForEach(p.avisos.prefix(5)) { LinhaAviso(aviso: $0) }
                            }
                            .padding(.vertical, 24)
                        }
                        .entrada(5)
                    }
                    Group {
                        Fio()
                        SecaoConferir().padding(.vertical, 24)
                    }
                    .entrada(6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .rolagemDeTeste()
            .background(Tema.fundo)
            .navigationTitle("Gastos do mês")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .entradaDeTela()
        .destinoZoom("analise")
    }
}

struct TodosAvisosView: View {
    var body: some View {
        ComPainel { p in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if p.avisos.isEmpty {
                        EstadoVazio(titulo: "Tudo certo", texto: "Nenhum aviso agora.")
                    }
                    ForEach(Array(p.avisos.enumerated()), id: \.element.id) { i, aviso in LinhaAviso(aviso: aviso).entrada(i) }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .rolagemDeTeste()
            .background(Tema.fundo)
            .navigationTitle("Avisos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .entradaDeTela()
    }
}
