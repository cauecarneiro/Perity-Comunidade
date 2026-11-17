import SwiftData
import SwiftUI
import PrumoCore

enum TextoRendimento {
    static func dinheiro(_ centavos: Int) -> String {
        (centavos >= 0 ? "+" : "−") + Dinheiro.formatar(abs(centavos))
    }

    static func percentual(_ fracao: Double, casas: Int = 1) -> String {
        let n = String(format: "%.\(casas)f", abs(fracao) * 100).replacingOccurrences(of: ".", with: ",")
        return (fracao >= 0 ? "+" : "−") + n + "%"
    }

    /// "108% do CDI"
    static func doCDI(_ fracao: Double) -> String {
        "\(Int((fracao * 100).rounded()))% do CDI"
    }
}

// MARK: - Tela (iPhone)

struct InvestimentosView: View {
    @State private var adicionando = false

    var body: some View {
        ComInvestimentos { p in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if p.ativos.isEmpty {
                        EstadoVazio(titulo: "Sem investimentos ainda",
                                    texto: "Conecte uma corretora em Ajustes ou adicione um investimento manualmente no +.")
                            .padding(.vertical, 22)
                            .entrada(0)
                    } else {
                        BlocoTotalInvestido(p: p).entrada(0)
                        Group {
                            Fio()
                            SecaoRendimento(p: p).padding(.vertical, 24)
                        }
                        .entrada(1)
                        Group {
                            Fio()
                            SecaoFechamento(p: p).padding(.vertical, 24)
                        }
                        .entrada(2)
                        Group {
                            Fio()
                            SecaoAlocacao(p: p).padding(.vertical, 24)
                        }
                        .entrada(3)
                        if !p.vencimentos.isEmpty {
                            Group {
                                Fio()
                                SecaoVencimentosInvestimentos(p: p).padding(.vertical, 24)
                            }
                            .entrada(4)
                        }
                        Group {
                            Fio()
                            SecaoItensInvestimentos(p: p).padding(.vertical, 24)
                        }
                        .entrada(5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .rolagemDeTeste()
            .background(Tema.fundo)
            .navigationTitle("Investimentos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adicionando = true } label: { Image(systemName: "plus").modifier(IconeDeBarra()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Adicionar investimento")
                }
                .semCapsula()
                BarraPrumo(secao: .investimentos)
            }
            .sheet(isPresented: $adicionando) {
                NavigationStack { NovoInvestimentoView() }
                    #if os(macOS)
                    .frame(minWidth: 440, minHeight: 440)
                    #endif
            }
        }
        .entradaDeTela(.investimentos)
    }
}

// MARK: - Seções (usadas no iPhone e no Mac)

/// O total, com a linha da evolução: ao passar o dedo, o número mostra quanto havia naquele dia.
struct BlocoTotalInvestido: View {
    let p: PainelInvestimentos
    var alturaGrafico: CGFloat = 120
    @State private var tocado: PontoEvolucao?

    var body: some View {
        BlocoMacro(rotulo: tocado.map { "Investido em " + $0.dia.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "pt_BR"))) } ?? "Total investido",
                   seta: false) {
            NumeroHeroi(centavos: tocado?.centavos ?? p.totalCentavos)
            if !p.evolucao.isEmpty {
                LinhaEvolucao(pontos: p.evolucao) { tocado = $0 }
                    .frame(height: alturaGrafico)
                    .padding(.top, 8)
            }
        }
    }
}

/// Quanto o dinheiro rende por mês e em 12 meses, em reais e em percentual, e quanto isso é do CDI.
struct SecaoRendimento: View {
    let p: PainelInvestimentos

    var body: some View {
        let r = p.rendimento
        let f = p.fechamento
        VStack(alignment: .leading, spacing: 18) {
            CabecalhoSecao(titulo: "Quanto rende")
            if r.mesCentavos == nil && r.dozeMesesCentavos == nil {
                Text("As instituições ainda não informaram o rendimento destes investimentos.")
                    .apoio().fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    if let c = r.mesCentavos, let pct = r.mesPercentual { coluna("Por mês", c, pct, f.percentualDoCDI) }
                    if let c = r.dozeMesesCentavos, let pct = r.dozeMesesPercentual { coluna("Em 12 meses", c, pct, f.percentualDoCDI12m) }
                }
                if let frase = fraseDoCDI(f) {
                    TextoPrivado(frase).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                }
                if let carteira = f.taxaMes, let cdi = f.cdiMes {
                    comparacao("No último mês", carteira, cdi, casas: 2)
                }
                if let carteira = f.taxa12m, let cdi = f.cdi12m {
                    comparacao("Em 12 meses", carteira, cdi, casas: 1)
                }
                Text(nota(r, f)).font(.caption).foregroundStyle(Tema.terciario).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func coluna(_ titulo: String, _ centavos: Int, _ pct: Double, _ doCDI: Double?) -> some View {
        let cor = centavos >= 0 ? Tema.acento : Tema.vermelho
        return VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.footnote).foregroundStyle(Tema.secundario)
            TextoPrivado(TextoRendimento.dinheiro(centavos))
                .font(.numero(24))
                .tracking(-0.5)
                .foregroundStyle(cor)
                .lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                Text(TextoRendimento.percentual(pct, casas: 2))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(cor)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(cor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                if let d = doCDI, d > 0 {
                    Text(TextoRendimento.doCDI(d))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Tema.secundario)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Duas barras na mesma escala: a carteira (limão) e o CDI (cinza).
    private func comparacao(_ titulo: String, _ carteira: Double, _ cdi: Double, casas: Int) -> some View {
        let maior = max(carteira, cdi, 0.0001)
        return VStack(alignment: .leading, spacing: 8) {
            Text(titulo).rotulo()
            barra("Sua carteira", carteira, maior, carteira >= 0 ? Tema.acento : Tema.vermelho, casas)
            barra("CDI", cdi, maior, Color.white.opacity(0.32), casas)
        }
    }

    private func barra(_ nome: String, _ valor: Double, _ maior: Double, _ cor: Color, _ casas: Int) -> some View {
        HStack(spacing: 10) {
            Text(nome).font(.caption).foregroundStyle(Tema.secundario).frame(width: 84, alignment: .leading)
            BarraProgresso(valor: max(0, valor) / maior, cor: cor, altura: 5)
            Text(TextoRendimento.percentual(valor, casas: casas))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Tema.texto)
                .frame(width: 64, alignment: .trailing)
        }
    }

    /// "No CDI, o mesmo dinheiro teria rendido R$ X": a comparação em reais.
    private func fraseDoCDI(_ f: FechamentoInvestimentos) -> String? {
        guard let rendeu = f.rendeuCentavos, let taxa = f.taxaMes, let cdi = f.cdiMes, taxa != 0 else { return nil }
        let noCDI = Int((Double(rendeu) / taxa * cdi).rounded())
        let diferenca = rendeu - noCDI
        let base = "No CDI, o mesmo dinheiro teria rendido \(Dinheiro.formatar(noCDI)) no mês"
        if abs(diferenca) < 100 { return base + ": empatou." }
        return diferenca > 0
            ? base + ". Você ganhou \(Dinheiro.formatar(diferenca)) a mais."
            : base + ". Você ganhou \(Dinheiro.formatar(-diferenca)) a menos."
    }

    private func nota(_ r: RendimentoCarteira, _ f: FechamentoInvestimentos) -> String {
        var texto = "Calculado pelas taxas que cada instituição informa, antes do imposto."
        let cobertos = max(r.mesCobertos, r.dozeMesesCobertos)
        if cobertos < r.totalInvestimentos {
            texto += " Considera \(cobertos) de \(r.totalInvestimentos) investimentos; os outros não informam taxa."
        }
        if f.cdiMes == nil { texto += " Sem internet não deu para buscar o CDI: a comparação volta quando houver conexão." }
        else { texto += " CDI do Banco Central." }
        return texto
    }
}

/// O balanço do mês que fechou: o que rendeu o CDI ou mais, o que ficou abaixo e o que perdeu valor.
struct SecaoFechamento: View {
    let p: PainelInvestimentos

    var body: some View {
        let f = p.fechamento
        VStack(alignment: .leading, spacing: 18) {
            CabecalhoSecao(titulo: "Fechamento de \(f.nomeDoMes)")
            TextoPrivado(f.frase).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            grupo(f.cdiMes == nil ? "Rendeu" : "Valeu a pena", f.cdiMes == nil ? nil : "rendeu o CDI ou mais", f.bateram, Tema.acento)
            grupo("Ficou abaixo do CDI", nil, f.abaixo, Tema.ambar)
            grupo("Perdeu valor", nil, f.perderam, Tema.vermelho)
            if !f.semDados.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sem dados do mês").rotulo()
                    Text(f.semDados.map(\.nome).joined(separator: ", "))
                        .font(.caption).foregroundStyle(Tema.secundario).fixedSize(horizontal: false, vertical: true)
                }
            }
            if f.itens.contains(where: \.isento) {
                Text("LCI, LCA, CRI e CRA não pagam imposto de renda: nelas, 85% do CDI já equivale a um CDB a 100%.")
                    .font(.caption).foregroundStyle(Tema.terciario).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func grupo(_ titulo: String, _ apoio: String?, _ itens: [ItemFechamento], _ cor: Color) -> some View {
        if !itens.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(cor).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(apoio.map { "\(titulo) · \($0)" } ?? titulo).rotulo()
                }
                ForEach(itens) { i in LinhaFechamento(item: i, cor: cor) }
            }
        }
    }
}

struct LinhaFechamento: View {
    let item: ItemFechamento
    let cor: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.nome).font(.body).lineLimit(1)
                    if item.isento { Selo(texto: "Isento") }
                }
                if let rendeu = item.rendeuCentavos, let taxa = item.taxaMes {
                    TextoPrivado("\(TextoRendimento.dinheiro(rendeu)) · \(TextoRendimento.percentual(taxa, casas: 2))")
                        .font(.caption).foregroundStyle(Tema.secundario).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let d = item.percentualDoCDI {
                Text(TextoRendimento.doCDI(d))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(cor)
            } else if let taxa = item.taxaMes {
                Text(TextoRendimento.percentual(taxa, casas: 2))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(cor)
            }
        }
    }
}

struct SecaoAlocacao: View {
    let p: PainelInvestimentos

    var body: some View {
        let maior = max(p.fatias.map(\.percentual).max() ?? 1, 0.0001)
        VStack(alignment: .leading, spacing: 16) {
            CabecalhoSecao(titulo: "Como está distribuído")
            ForEach(p.fatias.prefix(8)) { f in
                LinhaProporcao(titulo: f.classe.nome, centavos: f.centavos, fracao: f.percentual, barra: f.percentual / maior)
            }
        }
    }
}

struct SecaoVencimentosInvestimentos: View {
    let p: PainelInvestimentos

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CabecalhoSecao(titulo: "Próximos vencimentos")
            ForEach(Array(p.vencimentos.prefix(4)), id: \.externalID) { i in
                if let v = i.vencimento {
                    let dias = Datas.dias(de: Date(), ate: v)
                    LinhaValor(titulo: i.nome,
                               apoio: "\(v.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "pt_BR")))) · em \(dias) dias",
                               centavos: i.saldoCentavos,
                               corApoio: dias <= 30 ? Tema.ambar : Tema.secundario)
                }
            }
        }
    }
}

struct SecaoItensInvestimentos: View {
    let p: PainelInvestimentos

    var body: some View {
        let doCDI = Dictionary(p.fechamento.itens.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        VStack(alignment: .leading, spacing: 28) {
            ForEach(ClasseAtivo.allCases.filter { c in p.ativos.contains { $0.classe == c } }, id: \.self) { classe in
                let itens = p.ativos.filter { $0.classe == classe }
                VStack(alignment: .leading, spacing: 14) {
                    CabecalhoSecao(titulo: classe.nome) {
                        if itens.count > 1 {
                            Valor(centavos: itens.reduce(0) { $0 + $1.saldoCentavos })
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Tema.terciario)
                        }
                    }
                    ForEach(itens, id: \.externalID) { i in
                        NavigationLink { DetalheInvestimentoView(investimento: i) } label: { linha(i, doCDI[i.externalID]) }
                            .buttonStyle(.toque)
                    }
                }
            }
        }
    }

    private func linha(_ i: Investimento, _ fechamento: ItemFechamento?) -> some View {
        let detalhe = [i.codigo, i.instituicao.isEmpty ? nil : i.instituicao].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(i.nome).font(.body).lineLimit(1)
                if !detalhe.isEmpty { Text(detalhe).font(.caption).foregroundStyle(Tema.secundario).lineLimit(1) }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Valor(centavos: i.saldoCentavos).font(.numero(16, .medium))
                if let r = fechamento?.taxaMes {
                    let cdi = fechamento?.percentualDoCDI.map { " · " + TextoRendimento.doCDI($0) } ?? ""
                    Text("\(TextoRendimento.percentual(r, casas: 2)) no mês\(cdi)")
                        .font(.caption).foregroundStyle(r >= 0 ? Tema.acento : Tema.vermelho).lineLimit(1)
                }
            }
            Seta()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Detalhe e cadastro

struct DetalheInvestimentoView: View {
    @Bindable var investimento: Investimento
    @Environment(\.modelContext) private var contexto
    @Environment(\.painelInvestimentos) private var painel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(investimento.classe.nome).rotulo()
                    NumeroHeroi(centavos: investimento.saldoCentavos, tamanho: 44)
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }
            Section("Rendimento") {
                let fechamento = painel?.fechamento.itens.first { $0.id == investimento.externalID }
                if let r = investimento.rentabilidadeMes {
                    linha("No último mês", TextoRendimento.percentual(r, casas: 2) + (fechamento?.percentualDoCDI.map { " · " + TextoRendimento.doCDI($0) } ?? ""))
                }
                if let c = fechamento?.rendeuCentavos { linha("Rendeu no mês", TextoRendimento.dinheiro(c)) }
                if let r = investimento.rentabilidade12m {
                    linha("Em 12 meses", TextoRendimento.percentual(r, casas: 2) + (fechamento?.percentualDoCDI12m.map { " · " + TextoRendimento.doCDI($0) } ?? ""))
                }
                if let t = investimento.taxaAnual { linha("Taxa contratada ao ano", TextoRendimento.percentual(t, casas: 2).replacingOccurrences(of: "+", with: "")) }
                if investimento.rentabilidadeMes == nil && investimento.rentabilidade12m == nil && investimento.taxaAnual == nil {
                    Text("A instituição não informa o rendimento deste investimento.").foregroundStyle(Tema.secundario)
                }
            }
            Section("Dados") {
                if let q = investimento.quantidade { linha("Quantidade", q.formatted(.number.precision(.fractionLength(0...4)))) }
                if let c = investimento.valorCotaCentavos { linha("Valor da cota", Dinheiro.formatar(c)) }
                if let v = investimento.vencimento { linha("Vencimento", v.formatted(.dateTime.day().month().year().locale(Locale(identifier: "pt_BR")))) }
                if let e = investimento.emissor { linha("Emissor", e) }
                if !investimento.instituicao.isEmpty { linha("Instituição", investimento.instituicao) }
            }
            if investimento.manual {
                Section("Atualizar (manual)") {
                    HStack {
                        Text("Saldo atual")
                        Spacer()
                        TextField("0,00", value: Binding(get: { investimento.saldoCentavos.emReais },
                                                         set: { investimento.saldoCentavos = Dinheiro.centavos($0); investimento.atualizadoEm = Date() }),
                                  format: .number.precision(.fractionLength(2)))
                            .multilineTextAlignment(.trailing).frame(maxWidth: 160)
                    }
                    Button("Remover investimento", role: .destructive) {
                        contexto.delete(investimento)
                        try? contexto.save()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle(investimento.nome)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .formStyle(.grouped)
        #endif
        .onDisappear { try? contexto.save() }
    }

    private func linha(_ t: String, _ v: String) -> some View {
        HStack { Text(t); Spacer(); TextoPrivado(v).foregroundStyle(Tema.secundario).monospacedDigit() }
    }
}

struct NovoInvestimentoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @State private var nome = ""
    @State private var classe: ClasseAtivo = .cripto
    @State private var saldoTexto = ""
    @State private var codigo = ""

    var body: some View {
        Form {
            Section {
                TextField("Nome (ex.: Bitcoin, CDB do banco X)", text: $nome)
                Picker("Tipo", selection: $classe) {
                    ForEach(ClasseAtivo.allCases, id: \.self) { Text($0.nome).tag($0) }
                }
                TextField("Código (opcional, ex.: BTC, PETR4)", text: $codigo)
                TextField("Valor atual (R$)", text: $saldoTexto)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            } footer: {
                Text("Use para o que não vem pelo Open Finance: cripto, previdência em outro lugar, imóvel, etc. Atualize o valor quando quiser.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Novo investimento")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .formStyle(.grouped)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }.semCapsulaNoMac()
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    let i = Investimento(externalID: "manual-\(UUID().uuidString)", nome: nome, classe: classe,
                                         saldoCentavos: Dinheiro.ler(saldoTexto) ?? 0)
                    i.manual = true
                    i.instituicao = "Manual"
                    i.codigo = codigo.isEmpty ? nil : codigo
                    contexto.insert(i)
                    try? contexto.save()
                    dismiss()
                }
                .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty || Dinheiro.ler(saldoTexto) == nil)
            }.semCapsulaNoMac()
        }
    }
}
