import SwiftData
import SwiftUI
import PrumoCore

// As páginas do Mac. Cada uma monta os mesmos números do iPhone com as peças de PainelMac.swift.

private func textoDeData(_ d: Date) -> String {
    Texto.primeiraMaiuscula(d.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: "pt_BR"))))
}

private func percentual(_ fracao: Double) -> String {
    let pct = fracao * 100
    return pct > 0 && pct < 1 ? "<1%" : "\(Int(pct.rounded()))%"
}

// MARK: - Visão geral

struct VisaoGeralMac: View {
    @Environment(EstadoApp.self) private var estado

    private let colunasVencimentos = [
        ColunaBase(titulo: "O quê"),
        ColunaBase(titulo: "Quando", icone: "calendar", largura: 110),
        ColunaBase(titulo: "Valor", icone: "number", largura: 110, aDireita: true),
    ]
    private let colunasRecentes = [
        ColunaBase(titulo: "Lançamento"),
        ColunaBase(titulo: "Categoria", icone: "tag", largura: 170),
        ColunaBase(titulo: "Valor", icone: "number", largura: 110, aDireita: true),
    ]

    var body: some View {
        ComPainel { p in
            PaginaMac(titulo: "Visão geral", propriedades: [("Hoje", textoDeData(p.hoje))]) {
                HStack(alignment: .top, spacing: 12) {
                    MetricaMac(rotulo: "Saldo em conta", centavos: p.saldoCentavos, apoio: resumoContas(p)) { estado.pagina = .contas }
                    MetricaMac(rotulo: "Faturas dos cartões", centavos: p.faturasCentavos, apoio: resumoFaturas(p)) { estado.pagina = .cartoes }
                    MetricaMac(rotulo: "Gastos de \(p.nomeDoMes)", centavos: p.mes.despesasCentavos,
                               apoio: p.previsao.projetadoCentavos > 0 ? "Fecha o mês em \(Dinheiro.formatarInteiro(p.previsao.projetadoCentavos))" : "Sem gastos ainda") { estado.pagina = .gastos }
                    MetricaMac(rotulo: "Fixos: falta pagar", centavos: p.fixos.faltaCentavos,
                               apoio: p.fixos.quantidade == 0 ? "Monte a lista do mês" : "\(p.fixos.pagos) de \(p.fixos.quantidade) pagos",
                               cor: p.fixos.quantidade > 0 && p.fixos.faltaCentavos == 0 ? Tema.acento : Tema.texto) { estado.pagina = .fixos }
                }
                .padding(.top, 28)
                .entrada(1)

                if let aviso = p.avisos.first {
                    ChamadaMac(cor: Tema.cor(aviso.severidade), titulo: aviso.titulo, texto: aviso.texto)
                        .padding(.top, 12)
                        .entrada(1)
                }

                HStack(alignment: .top, spacing: 36) {
                    SecaoMac(titulo: "Vence em breve", ordem: 2) {
                        VStack(spacing: 0) {
                            CabecalhoBase(colunas: colunasVencimentos)
                            if p.vencimentos.isEmpty {
                                Text("Nada vence nos próximos 14 dias.").font(.system(size: 13)).foregroundStyle(Tema.secundario)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            }
                            ForEach(p.vencimentos.prefix(7)) { v in
                                let dias = Datas.dias(de: p.hoje, ate: v.data)
                                LinhaBase {
                                    Text(v.titulo).lineLimit(1).celula(colunasVencimentos[0])
                                    Text(Texto.primeiraMaiuscula(textoDoDia(v.data, hoje: p.hoje)))
                                        .foregroundStyle(dias <= 1 ? Tema.ambar : Tema.secundario).lineLimit(1)
                                        .celula(colunasVencimentos[1])
                                    Valor(centavos: v.valorCentavos).celula(colunasVencimentos[2])
                                }
                            }
                            RodapeBase(itens: [("CONTAGEM", "\(p.vencimentos.count)"),
                                               ("SOMA", Dinheiro.formatar(p.vencimentos.reduce(0) { $0 + $1.valorCentavos }))])
                        }
                    }
                    SecaoMac(titulo: "Últimos lançamentos", ordem: 2) {
                        Button { estado.abrirLancamentos(FiltroLancamentos()) } label: { RotuloLink(texto: "Ver todos") }
                            .buttonStyle(.plain)
                    } conteudo: {
                        VStack(spacing: 0) {
                            CabecalhoBase(colunas: colunasRecentes)
                            ForEach(p.recentes.prefix(7)) { l in
                                LinhaBase {
                                    HStack(spacing: 6) {
                                        Text(l.titulo).lineLimit(1)
                                        if l.origem == .carteira { Selo(texto: "Ao vivo", cor: Tema.acento) }
                                    }
                                    .celula(colunasRecentes[0])
                                    Group {
                                        if l.interno { EtiquetaMac(texto: "Entre contas") } else { EtiquetaMac(categoria: l.categoriaChave) }
                                    }
                                    .celula(colunasRecentes[1])
                                    Valor(centavos: l.valorCentavos, colorido: true).opacity(l.interno ? 0.5 : 1).celula(colunasRecentes[2])
                                }
                            }
                        }
                    }
                }

                if !p.destaques.isEmpty {
                    SecaoMac(titulo: "Destaques de \(p.nomeDoMes)", ordem: 3) {
                        Button { estado.pagina = .gastos } label: { RotuloLink(texto: "Gastos do mês") }.buttonStyle(.plain)
                    } conteudo: {
                        GradeDeDestaques(destaques: Array(p.destaques.prefix(4)), mes: p.hoje)
                    }
                }

                if p.avisos.count > 1 {
                    SecaoMac(titulo: "Para ficar de olho", ordem: 4) {
                        VStack(spacing: 8) {
                            ForEach(p.avisos.dropFirst().prefix(6)) { a in
                                ChamadaMac(cor: Tema.cor(a.severidade), titulo: a.titulo, texto: a.texto)
                            }
                        }
                    }
                }
            }
        }
    }

    private func resumoContas(_ p: PainelInicio) -> String {
        let c = p.quantasContas, b = p.bancos.count
        if c == 0 { return "Nenhuma conta conectada" }
        return "\(c) \(c == 1 ? "conta" : "contas") em \(b) \(b == 1 ? "banco" : "bancos")"
    }

    private func resumoFaturas(_ p: PainelInicio) -> String {
        if p.cartoes.isEmpty { return "Nenhum cartão conectado" }
        if let v = p.proximoVencimentoFatura { return "Próxima vence \(textoDoDia(v, hoje: p.hoje))" }
        return "\(p.cartoes.count) \(p.cartoes.count == 1 ? "cartão" : "cartões")"
    }
}

/// Os destaques do mês em duas colunas de chamadas. Os que falam de uma categoria abrem os lançamentos dela.
struct GradeDeDestaques: View {
    @Environment(EstadoApp.self) private var estado
    let destaques: [Destaque]
    let mes: Date

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)],
                  alignment: .leading, spacing: 10) {
            ForEach(destaques) { d in
                ChamadaMac(cor: cor(d.tom), rotulo: d.rotulo, titulo: d.titulo, texto: d.texto,
                           acao: d.categoriaChave.map { chave in
                               { estado.abrirLancamentos(FiltroLancamentos(categoria: chave, mes: mes, titulo: Categorias.info(chave).nome)) }
                           })
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func cor(_ tom: TomDestaque) -> Color {
        switch tom {
        case .bom: Tema.acento
        case .atencao: Tema.ambar
        case .neutro: Tema.terciario
        }
    }
}

// MARK: - Contas

struct ContasMac: View {
    @State private var aberta: Conta?
    @State private var adicionando = false

    private let colunas = [
        ColunaBase(titulo: "Conta"),
        ColunaBase(titulo: "Banco", icone: "building.columns", largura: 200),
        ColunaBase(titulo: "Tipo", icone: "tag", largura: 150),
        ColunaBase(titulo: "Do total", icone: "percent", largura: 140),
        ColunaBase(titulo: "Saldo", icone: "number", largura: 130, aDireita: true),
    ]

    var body: some View {
        ComPainel { p in
            let contas = p.bancos.flatMap(\.contas)
            PaginaMac(titulo: "Contas", propriedades: [("Bancos", "\(p.bancos.count)"), ("Contas", "\(p.quantasContas)")]) {
                HStack(alignment: .top, spacing: 12) {
                    MetricaMac(rotulo: "Saldo em conta", centavos: p.saldoCentavos, apoio: "Soma das contas que entram no total")
                    ForEach(p.bancos.prefix(3)) { b in
                        MetricaMac(rotulo: b.nome, centavos: b.totalCentavos,
                                   apoio: p.saldoCentavos > 0 ? "\(percentual(Double(max(b.totalCentavos, 0)) / Double(p.saldoCentavos))) do total" : nil)
                    }
                }
                .padding(.top, 28)
                .entrada(1)

                SecaoMac(titulo: "Todas as contas", ordem: 2) {
                    VStack(spacing: 0) {
                        CabecalhoBase(colunas: colunas)
                        ForEach(contas, id: \.externalID) { c in
                            LinhaBase(acao: { aberta = c }) {
                                Text(c.nomeExibicao).lineLimit(1).celula(colunas[0])
                                Text(c.instituicao.isEmpty ? "—" : c.instituicao).foregroundStyle(Tema.secundario).lineLimit(1).celula(colunas[1])
                                EtiquetaMac(texto: c.tipo.nome).celula(colunas[2])
                                Group {
                                    if c.contaNoPatrimonio, p.saldoCentavos > 0 {
                                        let fracao = Double(max(c.saldoCentavos, 0)) / Double(p.saldoCentavos)
                                        HStack(spacing: 8) {
                                            BarraProgresso(valor: fracao, altura: 3).frame(width: 70)
                                            Text(percentual(fracao)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Tema.secundario)
                                        }
                                    } else {
                                        Text(c.contaNoPatrimonio ? "—" : "Fora da soma").foregroundStyle(Tema.terciario)
                                    }
                                }
                                .celula(colunas[3])
                                Valor(centavos: c.saldoCentavos).celula(colunas[4])
                            }
                        }
                        LinhaNova(titulo: "Nova conta manual") { adicionando = true }
                        Fio()
                        RodapeBase(itens: [("CONTAGEM", "\(contas.count)"), ("SOMA", Dinheiro.formatar(p.saldoCentavos))])
                    }
                }

                if !p.conexoes.isEmpty {
                    SecaoMac(titulo: "Conexões com bancos", ordem: 3) {
                        SecaoConexoes(p: p)
                    }
                }
            }
            .sheet(item: $aberta) { c in FolhaMac { DetalheContaView(contaID: c.externalID) } }
            .sheet(isPresented: $adicionando) { FolhaMac(comFechar: false) { NovaContaView() } }
        }
    }
}

// MARK: - Cartões

struct CartoesMac: View {
    @State private var aberto: Conta?

    private let colunas = [
        ColunaBase(titulo: "Cartão"),
        ColunaBase(titulo: "Final", icone: "number", largura: 130),
        ColunaBase(titulo: "Uso do limite", icone: "percent", largura: 150),
        ColunaBase(titulo: "Vence", icone: "calendar", largura: 110),
        ColunaBase(titulo: "Limite livre", icone: "number", largura: 120, aDireita: true),
        ColunaBase(titulo: "Fatura", icone: "number", largura: 120, aDireita: true),
    ]
    private let colunasEmprestimos = [
        ColunaBase(titulo: "Contrato"),
        ColunaBase(titulo: "Parcelas", icone: "number", largura: 170),
        ColunaBase(titulo: "Próxima", icone: "calendar", largura: 110),
        ColunaBase(titulo: "Parcela", icone: "number", largura: 120, aDireita: true),
        ColunaBase(titulo: "Saldo devedor", icone: "number", largura: 130, aDireita: true),
    ]

    var body: some View {
        ComPainel { p in
            PaginaMac(titulo: "Cartões", propriedades: [("Cartões", "\(p.cartoes.count)")]) {
                HStack(alignment: .top, spacing: 12) {
                    MetricaMac(rotulo: "Faturas somadas", centavos: p.faturasCentavos,
                               apoio: p.proximoVencimentoFatura.map { "Próxima vence \(textoDoDia($0, hoje: p.hoje))" })
                    MetricaMac(rotulo: "Limite livre", centavos: p.limiteLivreCentavos,
                               apoio: p.limiteTotalCentavos > 0 ? "de \(Dinheiro.formatarInteiro(p.limiteTotalCentavos)) de limite" : nil)
                    MetricaMac(rotulo: "Limite usado",
                               texto: p.limiteTotalCentavos > 0 ? percentual(1 - Double(p.limiteLivreCentavos) / Double(p.limiteTotalCentavos)) : "—",
                               apoio: "Somando todos os cartões")
                }
                .padding(.top, 28)
                .entrada(1)

                SecaoMac(titulo: "Faturas", ordem: 2) {
                    VStack(spacing: 0) {
                        CabecalhoBase(colunas: colunas)
                        if p.cartoes.isEmpty {
                            Text("Os cartões aparecem quando o banco deles estiver conectado.").font(.system(size: 13))
                                .foregroundStyle(Tema.secundario).frame(maxWidth: .infinity, alignment: .leading).padding(8)
                        }
                        ForEach(p.cartoes, id: \.externalID) { c in
                            LinhaBase(acao: { aberto = c }) {
                                Text(c.nomeExibicao).lineLimit(1).celula(colunas[0])
                                Text([c.bandeira, c.final4.map { "•• \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
                                    .foregroundStyle(Tema.secundario).lineLimit(1).celula(colunas[1])
                                Group {
                                    if let uso = c.usoDoLimite {
                                        HStack(spacing: 8) {
                                            BarraProgresso(valor: uso, cor: uso > 0.8 ? Tema.vermelho : Tema.acento, altura: 3).frame(width: 80)
                                            Text(percentual(uso)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Tema.secundario)
                                        }
                                    } else {
                                        Text("—").foregroundStyle(Tema.terciario)
                                    }
                                }
                                .celula(colunas[2])
                                Group {
                                    if let v = c.vencimentoFatura {
                                        Text(Texto.primeiraMaiuscula(textoDoDia(v, hoje: p.hoje)))
                                            .foregroundStyle(Datas.dias(de: p.hoje, ate: v) <= 3 ? Tema.ambar : Tema.secundario)
                                    } else {
                                        Text("—").foregroundStyle(Tema.terciario)
                                    }
                                }
                                .lineLimit(1)
                                .celula(colunas[3])
                                Valor(centavos: c.disponivelCentavos ?? 0).foregroundStyle(Tema.secundario).celula(colunas[4])
                                Valor(centavos: max(c.saldoCentavos, 0)).celula(colunas[5])
                            }
                        }
                        RodapeBase(itens: [("CONTAGEM", "\(p.cartoes.count)"), ("SOMA", Dinheiro.formatar(p.faturasCentavos))])
                    }
                }

                if !p.emprestimos.isEmpty {
                    SecaoMac(titulo: "Empréstimos e financiamentos", ordem: 3) {
                        VStack(spacing: 0) {
                            CabecalhoBase(colunas: colunasEmprestimos)
                            ForEach(p.emprestimos, id: \.externalID) { e in
                                LinhaBase {
                                    Text(e.nome).lineLimit(1).celula(colunasEmprestimos[0])
                                    Text(e.parcelasRestantes.map { "\($0) restantes" } ?? "—").foregroundStyle(Tema.secundario).celula(colunasEmprestimos[1])
                                    Text(e.proximoVencimento?.diaMesCurto ?? "—").foregroundStyle(Tema.secundario).celula(colunasEmprestimos[2])
                                    Valor(centavos: e.parcelaCentavos ?? 0).foregroundStyle(Tema.secundario).celula(colunasEmprestimos[3])
                                    Valor(centavos: e.saldoDevedorCentavos ?? 0).celula(colunasEmprestimos[4])
                                }
                            }
                            RodapeBase(itens: [("CONTAGEM", "\(p.emprestimos.count)"),
                                               ("SOMA", Dinheiro.formatar(p.emprestimos.reduce(0) { $0 + ($1.saldoDevedorCentavos ?? 0) }))])
                        }
                    }
                }
            }
            .sheet(item: $aberto) { c in FolhaMac { DetalheContaView(contaID: c.externalID) } }
        }
    }
}

// MARK: - Gastos do mês

struct GastosMac: View {
    @Environment(EstadoApp.self) private var estado
    @State private var visao: ModoCategorias = .detalhe

    private let colunas = [
        ColunaBase(titulo: "Categoria"),
        ColunaBase(titulo: "Área", icone: "tag", largura: 210),
        ColunaBase(titulo: "Lançamentos", icone: "number", largura: 100, aDireita: true),
        ColunaBase(titulo: "Do mês", icone: "percent", largura: 150),
        ColunaBase(titulo: "Valor", icone: "number", largura: 130, aDireita: true),
    ]
    private let colunasAreas = [
        ColunaBase(titulo: "Área"),
        ColunaBase(titulo: "Categorias", icone: "tag", largura: 380),
        ColunaBase(titulo: "Do mês", icone: "percent", largura: 150),
        ColunaBase(titulo: "Valor", icone: "number", largura: 130, aDireita: true),
    ]

    var body: some View {
        ComPainel { p in
            PaginaMac(titulo: "Gastos do mês", propriedades: [("Mês", p.hoje.mesAno), ("Até", textoDeData(p.hoje))]) {
                HStack(alignment: .top, spacing: 12) {
                    MetricaMac(rotulo: "Gasto até hoje", centavos: p.mes.despesasCentavos,
                               apoio: "\(p.mes.porCategoria.count) categorias")
                    MetricaMac(rotulo: "Fecha o mês em", centavos: p.previsao.projetadoCentavos,
                               apoio: p.previsao.mediaMensalCentavos > 0 ? "Sua média: \(Dinheiro.formatarInteiro(p.previsao.mediaMensalCentavos))" : "No ritmo atual")
                    MetricaMac(rotulo: "Entrou", centavos: p.mes.receitasCentavos, apoio: "Receitas de \(p.nomeDoMes)")
                    MetricaMac(rotulo: p.mes.saldoCentavos >= 0 ? "Sobrou" : "Faltou", centavos: abs(p.mes.saldoCentavos),
                               apoio: p.mes.taxaDePoupanca.map { $0 >= 0 ? "\(percentual($0)) da renda" : "Saiu mais do que entrou" },
                               cor: p.mes.saldoCentavos >= 0 ? Tema.acento : Tema.ambar)
                }
                .padding(.top, 28)
                .entrada(1)

                SecaoMac(titulo: "Para onde foi", ordem: 2) {
                    VisoesBase(opcoes: [OpcaoSeletor(valor: ModoCategorias.detalhe, titulo: "Categorias"),
                                        OpcaoSeletor(valor: ModoCategorias.areas, titulo: "Áreas")],
                               selecionada: $visao)
                } conteudo: {
                    if p.mes.porCategoria.isEmpty {
                        Text("Sem gastos neste mês ainda.").font(.system(size: 13)).foregroundStyle(Tema.secundario)
                    } else {
                        switch visao {
                        case .detalhe: tabelaCategorias(p)
                        case .areas: tabelaAreas(p)
                        }
                    }
                }

                if !p.destaques.isEmpty {
                    SecaoMac(titulo: "Destaques", ordem: 3) {
                        GradeDeDestaques(destaques: p.destaques, mes: p.hoje)
                    }
                }

                HStack(alignment: .top, spacing: 36) {
                    SecaoRitmo(p: p, altura: 190).frame(maxWidth: .infinity)
                    SecaoFluxo(p: p, altura: 190).frame(maxWidth: .infinity)
                }
                .padding(.top, 40)
                .entrada(4)

                SecaoConferirMac().padding(.top, 40)
            }
        }
    }

    private func abrir(_ chave: String, _ p: PainelInicio) {
        estado.abrirLancamentos(FiltroLancamentos(categoria: chave, mes: p.hoje, titulo: Categorias.info(chave).nome))
    }

    private func tabelaCategorias(_ p: PainelInicio) -> some View {
        let maior = max(p.mes.porCategoria.map(\.percentual).max() ?? 1, 0.0001)
        return VStack(spacing: 0) {
            CabecalhoBase(colunas: colunas)
            ForEach(p.mes.porCategoria) { g in
                LinhaBase(acao: { abrir(g.chave, p) }) {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: g.info.corHex)).frame(width: 7, height: 7)
                        Text(g.info.nome).lineLimit(1)
                    }
                    .celula(colunas[0])
                    EtiquetaMac(texto: Categorias.area(de: g.chave).nome).celula(colunas[1])
                    Text("\(g.quantidade)").monospacedDigit().foregroundStyle(Tema.secundario).celula(colunas[2])
                    HStack(spacing: 8) {
                        BarraProgresso(valor: g.percentual / maior, altura: 3).frame(width: 80)
                        Text(percentual(g.percentual)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Tema.secundario)
                    }
                    .celula(colunas[3])
                    Valor(centavos: g.centavos).celula(colunas[4])
                }
            }
            RodapeBase(itens: [("CONTAGEM", "\(p.mes.porCategoria.count)"), ("SOMA", Dinheiro.formatar(p.mes.porCategoria.reduce(0) { $0 + $1.centavos }))])
        }
    }

    private func tabelaAreas(_ p: PainelInicio) -> some View {
        let maior = max(p.areas.map(\.percentual).max() ?? 1, 0.0001)
        return VStack(spacing: 0) {
            CabecalhoBase(colunas: colunasAreas)
            ForEach(p.areas) { a in
                LinhaBase {
                    Text(a.info.nome).fontWeight(.medium).lineLimit(1).celula(colunasAreas[0])
                    HStack(spacing: 5) {
                        ForEach(a.categorias.prefix(3)) { g in
                            Button { abrir(g.chave, p) } label: { EtiquetaMac(categoria: g.chave) }.buttonStyle(.plain)
                        }
                        if a.categorias.count > 3 {
                            Text("+\(a.categorias.count - 3)").font(.system(size: 12)).foregroundStyle(Tema.terciario)
                        }
                    }
                    .celula(colunasAreas[1])
                    HStack(spacing: 8) {
                        BarraProgresso(valor: a.percentual / maior, altura: 3).frame(width: 80)
                        Text(percentual(a.percentual)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Tema.secundario)
                    }
                    .celula(colunasAreas[2])
                    Valor(centavos: a.centavos).celula(colunasAreas[3])
                }
            }
            RodapeBase(itens: [("CONTAGEM", "\(p.areas.count)"), ("SOMA", Dinheiro.formatar(p.areas.reduce(0) { $0 + $1.centavos }))])
        }
    }
}

/// Base "Conferir categorias": cada loja, a categoria atual e o total; clicar abre a folha para corrigir.
struct SecaoConferirMac: View {
    @Environment(\.conferencia) private var conferencia
    @State private var lojas: [LojaConferida] = []
    @State private var mostrarTodas = false
    @State private var escolhendo: LojaConferida?

    private let colunas = [
        ColunaBase(titulo: "Loja"),
        ColunaBase(titulo: "Categoria", icone: "tag", largura: 230),
        ColunaBase(titulo: "Vezes", icone: "number", largura: 80, aDireita: true),
        ColunaBase(titulo: "Total", icone: "number", largura: 130, aDireita: true),
    ]

    var body: some View {
        SecaoMac(titulo: "Conferir categorias", ordem: 5) {
            if lojas.isEmpty {
                Text("Quando houver gastos, as lojas aparecem aqui.").font(.system(size: 13)).foregroundStyle(Tema.secundario)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Onde cada loja caiu nos últimos 12 meses, as que o app menos tem certeza primeiro. Clique na que estiver errada: a escolha vira regra, arruma as anteriores e vale para as próximas.")
                        .font(.system(size: 13)).foregroundStyle(Tema.secundario)
                    VStack(spacing: 0) {
                        CabecalhoBase(colunas: colunas)
                        ForEach(mostrarTodas ? lojas : Array(lojas.prefix(10))) { loja in
                            LinhaBase(acao: { escolhendo = loja }) {
                                HStack(spacing: 8) {
                                    Text(loja.nome).lineLimit(1)
                                    if loja.confianca < 50 { Selo(texto: "Incerto", cor: Tema.ambar) }
                                }
                                .celula(colunas[0])
                                EtiquetaMac(categoria: loja.categoriaChave).celula(colunas[1])
                                Text("\(loja.vezes)").monospacedDigit().foregroundStyle(Tema.secundario).celula(colunas[2])
                                Valor(centavos: loja.totalCentavos).celula(colunas[3])
                            }
                        }
                        if lojas.count > 10 {
                            Button { withAnimation(Movimento.rapida) { mostrarTodas.toggle() } } label: {
                                Text(mostrarTodas ? "Mostrar menos" : "Mostrar todas (\(lojas.count))")
                                    .font(.system(size: 13)).foregroundStyle(Tema.acento)
                                    .padding(.horizontal, 8).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                        RodapeBase(itens: [("CONTAGEM", "\(lojas.count)"), ("SOMA", Dinheiro.formatar(lojas.reduce(0) { $0 + $1.totalCentavos }))])
                    }
                }
            }
        }
        .task(id: conferencia.versao) { lojas = conferencia.lojas }
        .sheet(item: $escolhendo) { loja in FolhaMac(comFechar: false) { EscolherCategoriaView(loja: loja) } }
    }
}

// MARK: - Lançamentos

struct LancamentosMac: View {
    @Environment(EstadoApp.self) private var estado
    @Query(sort: [SortDescriptor(\Lancamento.data, order: .reverse), SortDescriptor(\Lancamento.criadoEm, order: .reverse)])
    private var todos: [Lancamento]
    @Query private var contas: [Conta]

    @State private var busca = ""
    @State private var periodo: PeriodoLista = .mesAtual
    @State private var categoria: String?
    @State private var mostrarInternos = false
    @State private var limite = 150
    @State private var selecionado: Lancamento?
    @State private var criando = false

    private let colunas = [
        ColunaBase(titulo: "Data", icone: "calendar", largura: 90),
        ColunaBase(titulo: "Lançamento"),
        ColunaBase(titulo: "Categoria", icone: "tag", largura: 200),
        ColunaBase(titulo: "Conta", icone: "building.columns", largura: 170),
        ColunaBase(titulo: "Valor", icone: "number", largura: 130, aDireita: true),
    ]

    private var filtrados: [Lancamento] {
        let (ini, fim) = periodo.intervalo(hoje: Date())
        let q = Texto.normalizar(busca)
        return todos.filter { l in
            guard l.conciliadoComID == nil, l.data >= ini, l.data < fim else { return false }
            if !mostrarInternos && (l.interno || l.ignorado) { return false }
            if let c = categoria, l.categoriaChave != c { return false }
            if !q.isEmpty {
                let alvo = Texto.normalizar(l.descricao + " " + (l.estabelecimento ?? "") + " " + l.categoria.nome + " " + (l.notas ?? ""))
                if !alvo.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        let lista = filtrados
        let nomes = Dictionary(contas.map { ($0.externalID, $0.nomeExibicao) }, uniquingKeysWith: { a, _ in a })
        let cartoes = Analise.idsDeCartao(contas)
        let (entrou, saiu) = totais(lista, cartoes: cartoes)
        PaginaMac(titulo: "Lançamentos", propriedades: [("Período", periodo.titulo), ("Categoria", categoria.map { Categorias.info($0).nome } ?? "Todas")]) {
            filtros.padding(.top, 26).entrada(1)

            VStack(spacing: 0) {
                CabecalhoBase(colunas: colunas)
                if lista.isEmpty {
                    Text("Nada encontrado. Ajuste os filtros ou o período.").font(.system(size: 13)).foregroundStyle(Tema.secundario)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                LazyVStack(spacing: 0) {
                    ForEach(lista.prefix(limite)) { l in
                        LinhaBase(acao: { selecionado = l }) {
                            Text(l.data.diaMesCurto).foregroundStyle(Tema.secundario).lineLimit(1).celula(colunas[0])
                            HStack(spacing: 6) {
                                Text(l.titulo).lineLimit(1)
                                if l.origem == .carteira { Selo(texto: "Ao vivo", cor: Tema.acento) }
                                if l.status == .pendente { Selo(texto: "Pendente", cor: Tema.ambar) }
                                if let a = l.parcelaAtual, let t = l.totalParcelas, t > 1 { Selo(texto: "\(a)/\(t)") }
                            }
                            .celula(colunas[1])
                            Group {
                                if l.interno { EtiquetaMac(texto: "Entre contas") } else { EtiquetaMac(categoria: l.categoriaChave) }
                            }
                            .celula(colunas[2])
                            Text(nomes[l.contaID] ?? "—").foregroundStyle(Tema.secundario).lineLimit(1).celula(colunas[3])
                            Valor(centavos: l.valorCentavos, colorido: true).opacity(l.interno ? 0.5 : 1).celula(colunas[4])
                        }
                    }
                }
                if lista.count > limite {
                    LinhaNova(titulo: "Mostrar mais (\(lista.count - limite) restantes)") { limite += 300 }
                    Fio()
                }
                LinhaNova(titulo: "Novo lançamento") { criando = true }
                Fio()
                RodapeBase(itens: [("CONTAGEM", "\(lista.count)"), ("ENTROU", Dinheiro.formatar(entrou)), ("SAIU", Dinheiro.formatar(saiu))])
            }
            .padding(.top, 14)
            .entrada(2)
        }
        .sheet(item: $selecionado) { l in FolhaMac(comFechar: false) { DetalheLancamentoView(lancamento: l) } }
        .sheet(isPresented: $criando) { FolhaMac(comFechar: false) { NovoLancamentoView() } }
        .onAppear { aplicar(estado.filtroDoMac) }
        .onChange(of: estado.filtroDoMac) { _, novo in aplicar(novo) }
    }

    private func aplicar(_ filtro: FiltroLancamentos) {
        categoria = filtro.categoria
        periodo = filtro.mes.map { Datas.inicioDoMes($0) == Datas.inicioDoMes(Date()) ? PeriodoLista.mesAtual : PeriodoLista.mes($0) } ?? .mesAtual
        limite = 150
    }

    private func totais(_ lista: [Lancamento], cartoes: Set<String>) -> (Int, Int) {
        var entrou = 0, saiu = 0
        for l in lista where l.contaParaRelatorios {
            if cartoes.contains(l.contaID) { saiu += -l.valorCentavos }
            else if l.valorCentavos > 0 { entrou += l.valorCentavos }
            else { saiu += -l.valorCentavos }
        }
        return (entrou, saiu)
    }

    /// Os filtros, como as "pílulas" de filtro de uma base.
    private var filtros: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach([PeriodoLista.mesAtual, .mesAnterior, .tresMeses, .ano, .tudo]) { p in
                    Button(p.titulo) { periodo = p }
                }
            } label: { pilula(periodo.titulo, icone: "calendar", ativa: periodo != .mesAtual) }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()

            Menu {
                Button("Todas as categorias") { categoria = nil }
                ForEach(Categorias.areas) { area in
                    let lista = Categorias.todas.filter { $0.area == area.chave }
                    if !lista.isEmpty {
                        Menu(area.nome) {
                            ForEach(lista) { c in Button(c.nome) { categoria = c.chave } }
                        }
                    }
                }
            } label: { pilula(categoria.map { Categorias.info($0).nome } ?? "Categoria", icone: "tag", ativa: categoria != nil) }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()

            Button { mostrarInternos.toggle() } label: { pilula("Entre contas", icone: "arrow.left.arrow.right", ativa: mostrarInternos) }
                .buttonStyle(.plain)

            if categoria != nil || periodo != .mesAtual || mostrarInternos || !busca.isEmpty {
                Button("Limpar") { categoria = nil; periodo = .mesAtual; mostrarInternos = false; busca = "" }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Tema.secundario)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(Tema.secundario)
                TextField("Buscar", text: $busca).textFieldStyle(.plain).font(.system(size: 13)).frame(width: 190)
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private func pilula(_ texto: String, icone: String, ativa: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icone).font(.system(size: 10))
            Text(texto).font(.system(size: 12.5)).lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .foregroundStyle(ativa ? Tema.sobreAcento : Tema.texto.opacity(0.86))
        .background(ativa ? Tema.acento : Color.white.opacity(0.08), in: Capsule())
        .contentShape(Capsule())
    }
}

// MARK: - Fixos

/// A página que substitui a planilha: uma base com caixinha, nome, categoria, forma e valor,
/// separada em "A pagar" e "Pagos", com contagem e soma no rodapé.
struct FixosMac: View {
    @State private var mes = Date()
    @State private var editando: Fixo?
    @State private var criando = false
    @State private var colando = false
    @Environment(\.accessibilityReduceMotion) private var reduzir

    private let recuo: CGFloat = 30
    private let colunas = [
        ColunaBase(titulo: "Gasto"),
        // Sete colunas: com mais, o nome do gasto some. A última cobrança fica no histórico da folha.
        ColunaBase(titulo: "Categoria", icone: "tag", largura: 130),
        ColunaBase(titulo: "De onde sai", icone: "creditcard", largura: 116),
        ColunaBase(titulo: "Dia", icone: "calendar", largura: 48, aDireita: true),
        ColunaBase(titulo: "Situação", icone: "checkmark.circle", largura: 182),
        ColunaBase(titulo: "Média 12 m", icone: "number", largura: 96, aDireita: true),
        ColunaBase(titulo: "Valor", icone: "number", largura: 104, aDireita: true),
    ]
    private let colunasSugestoes = [
        ColunaBase(titulo: "Aparece todo mês no extrato"),
        ColunaBase(titulo: "Categoria", icone: "tag", largura: 190),
        ColunaBase(titulo: "Valor", icone: "number", largura: 120, aDireita: true),
        ColunaBase(titulo: "", icone: "plus", largura: 90, aDireita: true),
    ]

    var body: some View {
        ComFixos(mes: mes) { p, acoes in
            PaginaMac(titulo: "Fixos") {
                HStack(spacing: 10) {
                    SeletorDeMes(mes: $mes).frame(width: 250)
                    Spacer(minLength: 0)
                    BotaoDePagina(titulo: "Colar uma lista", icone: "doc.on.clipboard") { colando = true }
                    BotaoDePagina(titulo: "Novo gasto fixo", icone: "plus", principal: true) { criando = true }
                }
                .padding(.top, 14)
                .entrada(0)

                HStack(alignment: .top, spacing: 12) {
                    MetricaMac(rotulo: "Falta pagar", centavos: p.resumo.faltaCentavos,
                               apoio: p.itens.isEmpty ? "Lista vazia"
                                   : p.proximoASair.flatMap { s in s.previsaoDebito.map { "próximo: \(s.nome), \($0.diaMesCurto)" } } ?? "em \(p.nomeDoMes)",
                               cor: !p.itens.isEmpty && p.resumo.faltaCentavos == 0 ? Tema.acento : Tema.texto)
                    MetricaMac(rotulo: "Já pago", centavos: p.resumo.pagoCentavos, apoio: "\(p.resumo.pagos) de \(p.resumo.quantidade) itens")
                    MetricaMac(rotulo: "Total do mês", centavos: p.resumo.totalCentavos, apoio: "Soma de todos os fixos")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Andamento").rotulo()
                        Text("\(p.resumo.pagos) de \(p.resumo.quantidade)").font(.numero(30)).tracking(-0.9)
                        BarraSegmentos(total: p.resumo.quantidade, feitos: p.resumo.pagos)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                    .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.top, 18)
                .entrada(1)

                SecaoMac(titulo: "Contas de \(p.nomeDoMes)", ordem: 2) {
                    VStack(spacing: 0) {
                        CabecalhoBase(colunas: colunas, recuo: recuo)
                        if p.itens.isEmpty {
                            Text("O que você paga todo mês entra aqui. O que sair no cartão ou na conta é marcado sozinho; Pix e boleto você marca com um clique.")
                                .font(.system(size: 13)).foregroundStyle(Tema.secundario)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                        }
                        grupo("A pagar", p.aPagar, acoes)
                        grupo("Pagos", p.pagos, acoes)
                        LinhaNova(titulo: "Novo gasto fixo") { criando = true }
                        Fio()
                        RodapeBase(itens: [("CONTAGEM", "\(p.itens.count)"), ("SOMA", Dinheiro.formatar(p.resumo.totalCentavos))])
                    }
                }

                if !p.sugestoes.isEmpty {
                    SecaoMac(titulo: "Talvez falte na lista", ordem: 3) {
                        VStack(spacing: 0) {
                            CabecalhoBase(colunas: colunasSugestoes)
                            ForEach(p.sugestoes.prefix(8)) { r in
                                LinhaBase {
                                    Text(r.nome).lineLimit(1).celula(colunasSugestoes[0])
                                    EtiquetaMac(categoria: r.categoriaChave).celula(colunasSugestoes[1])
                                    Valor(centavos: r.valorCentavos).celula(colunasSugestoes[2])
                                    Button("Adicionar") {
                                        withAnimation(reduzir ? nil : Movimento.suave) { acoes.adicionar(r, ehCartao: p.cartoes.contains(r.contaID)) }
                                    }
                                    .buttonStyle(.plain).font(.system(size: 13, weight: .medium)).foregroundStyle(Tema.acento)
                                    .celula(colunasSugestoes[3])
                                }
                            }
                        }
                    }
                }
            }
            .sheet(item: $editando) { f in
                FolhaMac(comFechar: false) { EditarFixoView(fixo: f, situacao: p.situacao(f.uid), contas: p.contas, acoes: acoes, mes: mes) }
            }
            .sheet(isPresented: $criando) {
                FolhaMac(comFechar: false) { EditarFixoView(fixo: nil, situacao: nil, contas: p.contas, acoes: acoes, mes: mes) }
            }
            .sheet(isPresented: $colando) { FolhaMac(comFechar: false) { ColarFixosView(acoes: acoes) } }
        }
    }

    @ViewBuilder private func grupo(_ titulo: String, _ itens: [SituacaoFixo], _ acoes: AcoesFixos) -> some View {
        if !itens.isEmpty {
            HStack(spacing: 8) {
                Text(titulo).font(.system(size: 13, weight: .semibold))
                Text("\(itens.count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Tema.terciario)
                Spacer(minLength: 8)
                Valor(centavos: itens.reduce(0) { $0 + $1.valorCentavos }).font(.system(size: 12, design: .monospaced)).foregroundStyle(Tema.secundario)
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .overlay(alignment: .bottom) { Fio() }
            ForEach(itens) { s in linha(s, acoes) }
        }
    }

    private func linha(_ s: SituacaoFixo, _ acoes: AcoesFixos) -> some View {
        LinhaBase(acao: { editando = acoes.fixo(s.uid) }) {
            Button {
                withAnimation(reduzir ? nil : Movimento.suave) { acoes.alternar(s, mes: mes) }
            } label: {
                Caixinha(marcada: s.pago, tamanho: 18).frame(width: recuo, height: 30, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(s.pago ? "Desmarcar \(s.nome)" : "Marcar \(s.nome) como pago")

            HStack(spacing: 6) {
                Text(s.nome).lineLimit(1).foregroundStyle(s.pago ? Tema.secundario : Tema.texto)
                if let a = s.parcelaAtual, let t = s.totalParcelas { Selo(texto: "\(a)/\(t)") }
                if acoes.fixo(s.uid)?.automatico == true {
                    Text("detectado").font(.system(size: 10, design: .monospaced)).foregroundStyle(Tema.terciario)
                }
            }
            .celula(colunas[0])
            EtiquetaMac(categoria: s.categoriaChave).celula(colunas[1])
            EtiquetaMac(texto: s.contaNome ?? s.forma.nome).celula(colunas[2])
            Text(s.diaTipico.map { "\($0)" } ?? "—").font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(s.diaTipico == nil ? Tema.terciario : Tema.secundario).celula(colunas[3])
            Group {
                if s.acumula, !s.pago, s.valorCentavos > 0 {
                    HStack(spacing: 8) {
                        BarraProgresso(valor: Double(s.gastoCentavos) / Double(s.valorCentavos),
                                       cor: s.gastoCentavos > s.valorCentavos ? Tema.ambar : Tema.acento, altura: 3).frame(width: 60)
                        TextoPrivado("\(Dinheiro.formatarInteiro(s.gastoCentavos)) até agora").font(.system(size: 12)).foregroundStyle(Tema.secundario).lineLimit(1)
                    }
                } else {
                    Text(situacao(s)).font(.system(size: 12.5)).foregroundStyle(s.pago ? Tema.acento : Tema.secundario).lineLimit(1)
                }
            }
            .celula(colunas[4])
            Group {
                if let media = mediaDoHistorico(s) {
                    Valor(centavos: media).font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Tema.secundario)
                } else {
                    Text("—").foregroundStyle(Tema.terciario)
                }
            }
            .celula(colunas[5])
            Valor(centavos: s.valorCentavos).foregroundStyle(s.pago ? Tema.secundario : Tema.texto).celula(colunas[6])
        }
    }

    /// Média do que saiu por mês com cobrança, nos últimos 12 meses.
    private func mediaDoHistorico(_ s: SituacaoFixo) -> Int? {
        var porMes: [String: Int] = [:]
        for c in s.historico { porMes[c.mes, default: 0] += c.valorCentavos }
        guard !porMes.isEmpty else { return nil }
        return porMes.values.reduce(0, +) / porMes.count
    }

    private func situacao(_ s: SituacaoFixo) -> String {
        if s.acumula { return "Mês fechado" }
        if s.pago {
            if s.detectado, let d = s.dataPagamento {
                if s.ehCartao, s.origemPrevisao == .fatura, let debito = s.previsaoDebito, debito > d {
                    // O dia da cobrança já está na coluna "Dia".
                    return "Cobrado · debita \(debito.diaMesCurto)"
                }
                return "Pago em \(d.diaMesCurto)"
            }
            return "Marcado por você"
        }
        if s.manual && s.detectado { return "Você desmarcou" }
        if let d = s.previsaoDebito {
            return s.origemPrevisao == .fatura ? "Debita \(d.diaMesCurto) (fatura)" : "Costuma sair dia \(Datas.calendario.component(.day, from: d))"
        }
        return "Ainda não apareceu no extrato"
    }
}

// MARK: - Investimentos

struct InvestimentosMac: View {
    @State private var aberto: Investimento?
    @State private var adicionando = false

    private let colunasFechamento = [
        ColunaBase(titulo: "Investimento"),
        ColunaBase(titulo: "Tipo", icone: "tag", largura: 170),
        ColunaBase(titulo: "Rendeu", icone: "number", largura: 120, aDireita: true),
        ColunaBase(titulo: "No mês", icone: "percent", largura: 90, aDireita: true),
        ColunaBase(titulo: "Do CDI", icone: "percent", largura: 90, aDireita: true),
        ColunaBase(titulo: "Resultado", icone: "checkmark.circle", largura: 150),
    ]
    private let colunasCarteira = [
        ColunaBase(titulo: "Investimento"),
        ColunaBase(titulo: "Tipo", icone: "tag", largura: 170),
        ColunaBase(titulo: "Onde", icone: "building.columns", largura: 150),
        ColunaBase(titulo: "Vence", icone: "calendar", largura: 110),
        ColunaBase(titulo: "12 meses", icone: "percent", largura: 90, aDireita: true),
        ColunaBase(titulo: "Saldo", icone: "number", largura: 130, aDireita: true),
    ]

    var body: some View {
        ComInvestimentos { p in
            let f = p.fechamento
            PaginaMac(titulo: "Investimentos", propriedades: [("Investimentos", "\(p.ativos.count)"),
                                                              ("CDI de \(f.nomeDoMes)", f.cdiMes.map { TextoRendimento.percentual($0, casas: 2).replacingOccurrences(of: "+", with: "") } ?? "Sem conexão para buscar")]) {
                if p.ativos.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Conecte uma corretora em Ajustes ou adicione um investimento manualmente.")
                            .font(.system(size: 14)).foregroundStyle(Tema.secundario)
                        BotaoDePagina(titulo: "Adicionar investimento", icone: "plus", principal: true) { adicionando = true }
                    }
                    .padding(.top, 28)
                    .entrada(1)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        MetricaMac(rotulo: "Total investido", centavos: p.totalCentavos, apoio: "\(p.ativos.count) investimentos")
                        MetricaMac(rotulo: "Rende por mês", texto: p.rendimento.mesCentavos.map(TextoRendimento.dinheiro) ?? "—",
                                   apoio: p.rendimento.mesPercentual.map { "\(TextoRendimento.percentual($0, casas: 2)) no último mês" },
                                   cor: (p.rendimento.mesCentavos ?? 0) >= 0 ? Tema.acento : Tema.vermelho)
                        MetricaMac(rotulo: "Do CDI no mês", texto: f.percentualDoCDI.map { percentual($0) } ?? "—",
                                   apoio: f.percentualDoCDI.map { $0 >= 1 ? "Ganhou do CDI" : "Abaixo do CDI" } ?? "Sem a taxa do mês",
                                   cor: (f.percentualDoCDI ?? 0) >= 1 ? Tema.acento : Tema.texto)
                        MetricaMac(rotulo: "Em 12 meses", texto: p.rendimento.dozeMesesCentavos.map(TextoRendimento.dinheiro) ?? "—",
                                   apoio: apoioDozeMeses(p),
                                   cor: (p.rendimento.dozeMesesCentavos ?? 0) >= 0 ? Tema.acento : Tema.vermelho)
                    }
                    .padding(.top, 28)
                    .entrada(1)

                    ChamadaMac(cor: (f.percentualDoCDI ?? 0) >= 1 ? Tema.acento : Tema.secundario,
                               rotulo: "Fechamento de \(f.nomeDoMes)", titulo: f.frase,
                               texto: "\(f.bateram.count) valeram a pena, \(f.abaixo.count) ficaram abaixo do CDI, \(f.perderam.count) perderam valor\(f.semDados.isEmpty ? "" : ", \(f.semDados.count) sem dados").")
                        .padding(.top, 12)
                        .entrada(1)

                    HStack(alignment: .top, spacing: 36) {
                        VStack(alignment: .leading, spacing: 14) {
                            CabecalhoSecao(titulo: "Evolução do total")
                            if p.evolucao.isEmpty {
                                Text("O gráfico aparece depois de alguns dias de uso.").font(.system(size: 13)).foregroundStyle(Tema.secundario)
                            } else {
                                LinhaEvolucao(pontos: p.evolucao).frame(height: 250)
                            }
                        }
                        .padding(.top, 22)
                        .frame(maxWidth: .infinity)
                        SecaoRendimento(p: p).padding(.top, 22).frame(maxWidth: .infinity)
                    }
                    .padding(.top, 22)
                    .entrada(2)

                    SecaoMac(titulo: "Fechamento de \(f.nomeDoMes)", ordem: 3) {
                        VStack(spacing: 0) {
                            CabecalhoBase(colunas: colunasFechamento)
                            ForEach(f.itens) { i in
                                LinhaBase {
                                    HStack(spacing: 6) {
                                        Text(i.nome).lineLimit(1)
                                        if i.isento { Selo(texto: "Isento") }
                                    }
                                    .celula(colunasFechamento[0])
                                    EtiquetaMac(texto: i.classe.nome).celula(colunasFechamento[1])
                                    TextoPrivado(i.rendeuCentavos.map(TextoRendimento.dinheiro) ?? "—").monospacedDigit()
                                        .foregroundStyle(cor(i.veredito)).celula(colunasFechamento[2])
                                    Text(i.taxaMes.map { TextoRendimento.percentual($0, casas: 2) } ?? "—").monospacedDigit()
                                        .foregroundStyle(Tema.secundario).celula(colunasFechamento[3])
                                    Text(i.percentualDoCDI.map { percentual($0) } ?? "—").monospacedDigit().celula(colunasFechamento[4])
                                    EtiquetaMac(texto: nome(i.veredito, comCDI: f.cdiMes != nil), cor: cor(i.veredito)).celula(colunasFechamento[5])
                                }
                            }
                            RodapeBase(itens: [("CONTAGEM", "\(f.itens.count)"),
                                               ("RENDEU", f.rendeuCentavos.map(TextoRendimento.dinheiro) ?? "—")])
                            if f.itens.contains(where: \.isento) {
                                Text("LCI, LCA, CRI e CRA não pagam imposto de renda: nelas, 85% do CDI já equivale a um CDB a 100%. A comparação é antes do imposto.")
                                    .font(.system(size: 12)).foregroundStyle(Tema.terciario)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
                            }
                        }
                    }

                    SecaoMac(titulo: "Carteira", ordem: 4) {
                        VStack(spacing: 0) {
                            CabecalhoBase(colunas: colunasCarteira)
                            ForEach(p.ativos, id: \.externalID) { i in
                                LinhaBase(acao: { aberto = i }) {
                                    HStack(spacing: 6) {
                                        Text(i.nome).lineLimit(1)
                                        if let c = i.codigo, !c.isEmpty { Selo(texto: c) }
                                    }
                                    .celula(colunasCarteira[0])
                                    EtiquetaMac(texto: i.classe.nome).celula(colunasCarteira[1])
                                    Text(i.instituicao.isEmpty ? "—" : i.instituicao).foregroundStyle(Tema.secundario).lineLimit(1).celula(colunasCarteira[2])
                                    Text(i.vencimento.map { $0.formatted(.dateTime.month(.abbreviated).year().locale(Locale(identifier: "pt_BR"))) } ?? "—")
                                        .foregroundStyle(Tema.secundario).lineLimit(1).celula(colunasCarteira[3])
                                    Text(i.rentabilidade12m.map { TextoRendimento.percentual($0) } ?? "—").monospacedDigit()
                                        .foregroundStyle((i.rentabilidade12m ?? 0) >= 0 ? Tema.secundario : Tema.vermelho).celula(colunasCarteira[4])
                                    Valor(centavos: i.saldoCentavos).celula(colunasCarteira[5])
                                }
                            }
                            LinhaNova(titulo: "Adicionar investimento manual") { adicionando = true }
                            Fio()
                            RodapeBase(itens: [("CONTAGEM", "\(p.ativos.count)"), ("SOMA", Dinheiro.formatar(p.totalCentavos))])
                        }
                    }

                    HStack(alignment: .top, spacing: 36) {
                        SecaoAlocacao(p: p).frame(maxWidth: .infinity)
                        if !p.vencimentos.isEmpty {
                            SecaoVencimentosInvestimentos(p: p).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 40)
                    .entrada(5)
                }
            }
            .sheet(item: $aberto) { i in FolhaMac { DetalheInvestimentoView(investimento: i) } }
            .sheet(isPresented: $adicionando) { FolhaMac(comFechar: false) { NovoInvestimentoView() } }
        }
    }

    private func apoioDozeMeses(_ p: PainelInvestimentos) -> String? {
        guard let pct = p.rendimento.dozeMesesPercentual else { return nil }
        let base = TextoRendimento.percentual(pct)
        return p.fechamento.percentualDoCDI12m.map { "\(base) · \(percentual($0)) do CDI" } ?? base
    }

    private func cor(_ v: VereditoInvestimento) -> Color {
        switch v {
        case .bateu: Tema.acento
        case .abaixo: Tema.ambar
        case .perdeu: Tema.vermelho
        case .semDados: Tema.terciario
        }
    }

    private func nome(_ v: VereditoInvestimento, comCDI: Bool) -> String {
        switch v {
        case .bateu: comCDI ? "Valeu a pena" : "Rendeu"
        case .abaixo: "Abaixo do CDI"
        case .perdeu: "Perdeu valor"
        case .semDados: "Sem dados"
        }
    }
}
