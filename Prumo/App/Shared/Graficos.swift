import Charts
import SwiftUI
import PrumoCore

// Gráficos do Perity: limão para o foco, cinza para a comparação, sobre preto. Sem degradê, sem brilho.

private func eixoCompacto(_ d: Double) -> String {
    Dinheiro.formatarCompacto(Int(d * 100)).replacingOccurrences(of: "R$ ", with: "")
}

private let grade = StrokeStyle(lineWidth: 0.5)
private let corComparacao = Color.white.opacity(0.28)

struct PontoEvolucao: Identifiable, Equatable {
    let dia: Date
    let centavos: Int
    var id: Date { dia }
}

// MARK: - Evolução

/// Uma linha no tempo. Ao passar o dedo (ou o ponteiro), avisa qual dia está tocado,
/// para o número grande da tela acompanhar.
struct LinhaEvolucao: View {
    let pontos: [PontoEvolucao]
    var aoTocar: (PontoEvolucao?) -> Void = { _ in }
    @State private var selecionado: Date?

    private var tocado: PontoEvolucao? {
        guard let s = selecionado else { return nil }
        return pontos.min { abs($0.dia.timeIntervalSince(s)) < abs($1.dia.timeIntervalSince(s)) }
    }

    var body: some View {
        let minimo = (pontos.map(\.centavos).min() ?? 0).emReais
        let maximo = (pontos.map(\.centavos).max() ?? 0).emReais
        let folga = max((maximo - minimo) * 0.15, 100)
        Chart {
            ForEach(pontos) { p in
                LineMark(x: .value("Dia", p.dia), y: .value("Valor", p.centavos.emReais))
                    .foregroundStyle(Tema.acento)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let p = tocado {
                RuleMark(x: .value("Dia", p.dia))
                    .foregroundStyle(Tema.terciario)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Dia", p.dia), y: .value("Valor", p.centavos.emReais))
                    .symbolSize(70).foregroundStyle(Tema.acento)
            } else if let u = pontos.last {
                PointMark(x: .value("Dia", u.dia), y: .value("Valor", u.centavos.emReais))
                    .symbolSize(40).foregroundStyle(Tema.acento)
            }
        }
        .chartYScale(domain: (minimo - folga)...(maximo + folga))
        .chartXSelection(value: $selecionado)
        .chartXScale(range: .plotDimension(padding: 6))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Locale(identifier: "pt_BR")))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Tema.terciario)
            }
        }
        .chartYAxis(.hidden)
        .onChange(of: tocado) { _, novo in aoTocar(novo) }
        .sensoryFeedback(.selection, trigger: tocado?.dia)
        .desenhaAoEntrar()
        .accessibilityLabel("Evolução no tempo")
    }
}

// MARK: - Ritmo do mês

/// Gasto acumulado: este mês (limão) contra o mês passado (cinza).
struct RitmoDoMes: View {
    @Environment(\.valoresOcultos) private var oculto
    let pontos: [PontoRitmo]

    var body: some View {
        Chart {
            ForEach(pontos) { p in
                LineMark(x: .value("Dia", p.dia), y: .value("Valor", p.anteriorCentavos.emReais), series: .value("Série", "Mês passado"))
                    .foregroundStyle(corComparacao)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .interpolationMethod(.stepEnd)
                if let a = p.atualCentavos {
                    LineMark(x: .value("Dia", p.dia), y: .value("Valor", a.emReais), series: .value("Série", "Este mês"))
                        .foregroundStyle(Tema.acento)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.stepEnd)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: [1, 8, 15, 22, 29]) { v in
                AxisValueLabel {
                    if let d = v.as(Int.self) { Text("\(d)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Tema.terciario) }
                }
            }
        }
        .chartYAxis { eixoY(oculto: oculto) }
        .desenhaAoEntrar()
    }
}

// MARK: - Entrou e saiu

/// Receitas (cinza) e despesas (limão) dos últimos meses.
struct BarrasMensais: View {
    @Environment(\.valoresOcultos) private var oculto
    let pontos: [PontoMensal]

    var body: some View {
        Chart {
            ForEach(pontos) { p in
                BarMark(x: .value("Mês", p.mes, unit: .month),
                        y: .value("Valor", p.receitasCentavos.emReais),
                        width: .ratio(0.3))
                    .foregroundStyle(by: .value("Tipo", "Entrou"))
                    .position(by: .value("Tipo", "Entrou"))
                    .cornerRadius(3)
                BarMark(x: .value("Mês", p.mes, unit: .month),
                        y: .value("Valor", p.despesasCentavos.emReais),
                        width: .ratio(0.3))
                    .foregroundStyle(by: .value("Tipo", "Saiu"))
                    .position(by: .value("Tipo", "Saiu"))
                    .cornerRadius(3)
            }
        }
        .chartForegroundStyleScale(["Entrou": corComparacao, "Saiu": Tema.acento])
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Locale(identifier: "pt_BR")))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Tema.terciario)
            }
        }
        .chartYAxis { eixoY(oculto: oculto) }
        .chartLegend(.hidden)
        .desenhaAoEntrar(deBaixo: true)
    }
}

private func eixoY(oculto: Bool) -> some AxisContent {
    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
        AxisGridLine(stroke: grade).foregroundStyle(Tema.linha)
        AxisValueLabel {
            if !oculto, let d = v.as(Double.self) {
                Text(eixoCompacto(d)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Tema.terciario)
            }
        }
    }
}

/// Legenda de duas séries: a de foco (limão) e a de comparação (cinza).
struct LegendaDupla: View {
    let foco: String
    let comparacao: String

    var body: some View {
        HStack(spacing: 16) {
            item(foco, Tema.acento)
            item(comparacao, corComparacao)
        }
        .font(.caption)
        .foregroundStyle(Tema.secundario)
    }

    private func item(_ texto: String, _ cor: Color) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(cor).frame(width: 12, height: 3)
            Text(texto)
        }
    }
}

// MARK: - Proporção

/// Uma linha de "quanto isso pesa no total": nome, percentual, valor e uma barra fina.
struct LinhaProporcao: View {
    let titulo: String
    let centavos: Int
    /// 0…1: participação no total.
    let fracao: Double
    /// 0…1: tamanho da barra (em geral, relativo ao maior item da lista).
    var barra: Double?
    var apoio: String?
    var seta = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(titulo).font(.body).lineLimit(1)
                Text(textoDaFracao)
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(Tema.secundario)
                Spacer(minLength: 8)
                Valor(centavos: centavos).font(.numero(16, .medium))
                if seta { Seta() }
            }
            BarraProgresso(valor: barra ?? fracao, altura: 3)
            if let apoio { Text(apoio).font(.caption).foregroundStyle(Tema.terciario).lineLimit(1) }
        }
        .contentShape(Rectangle())
    }

    private var textoDaFracao: String {
        let pct = fracao * 100
        return pct > 0 && pct < 1 ? "<1%" : "\(Int(pct.rounded()))%"
    }
}

/// Gastos por categoria, do maior para o menor. Tocar abre os lançamentos da categoria no mês.
struct ListaCategorias: View {
    let gastos: [GastoCategoria]
    var limite = 6
    var mes: Date?

    var body: some View {
        let maior = max(gastos.map(\.percentual).max() ?? 1, 0.0001)
        VStack(spacing: 18) {
            ForEach(gastos.prefix(limite)) { g in
                NavigationLink(value: Destino.lancamentos(FiltroLancamentos(categoria: g.chave, mes: mes, titulo: g.info.nome))) {
                    LinhaProporcao(titulo: g.info.nome, centavos: g.centavos, fracao: g.percentual, barra: g.percentual / maior,
                                   apoio: "\(Categorias.area(de: g.chave).nome) · \(g.quantidade) \(g.quantidade == 1 ? "lançamento" : "lançamentos")",
                                   seta: true)
                }
                .buttonStyle(.toque)
            }
        }
    }
}

/// Gastos juntos por área (Carro e transporte, Alimentação…), com as categorias de cada uma embaixo.
struct ListaAreas: View {
    let areas: [GastoArea]
    var mes: Date?

    var body: some View {
        let maior = max(areas.map(\.percentual).max() ?? 1, 0.0001)
        VStack(alignment: .leading, spacing: 26) {
            ForEach(areas) { a in
                VStack(alignment: .leading, spacing: 12) {
                    LinhaProporcao(titulo: a.info.nome, centavos: a.centavos, fracao: a.percentual, barra: a.percentual / maior)
                        .fontWeight(.semibold)
                    ForEach(a.categorias) { g in
                        NavigationLink(value: Destino.lancamentos(FiltroLancamentos(categoria: g.chave, mes: mes, titulo: g.info.nome))) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(g.info.nome).font(.subheadline).foregroundStyle(Tema.secundario).lineLimit(1)
                                Spacer(minLength: 8)
                                Valor(centavos: g.centavos).font(.numero(14, .regular)).foregroundStyle(Tema.secundario)
                                Seta()
                            }
                            .padding(.leading, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.toque)
                    }
                }
            }
        }
    }
}

/// Um gráfico mínimo e invisível. A primeira vez que o app desenha um gráfico custa alguns décimos de segundo;
/// fazer isso durante a abertura tira essa espera da primeira visita a Investimentos e a Gastos do mês.
struct AquecimentoDeGraficos: View {
    var body: some View {
        Chart {
            LineMark(x: .value("x", 0), y: .value("y", 0))
            LineMark(x: .value("x", 1), y: .value("y", 1))
            BarMark(x: .value("x", 2), y: .value("y", 1))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 24, height: 24)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
