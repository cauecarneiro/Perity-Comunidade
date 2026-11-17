import SwiftUI
import WidgetKit
import PrumoCore

struct EntradaPrumo: TimelineEntry {
    let date: Date
    let snapshot: SnapshotWidget
    let temDados: Bool
}

struct ProvedorPrumo: TimelineProvider {
    func placeholder(in context: Context) -> EntradaPrumo {
        EntradaPrumo(date: Date(), snapshot: .exemplo, temDados: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (EntradaPrumo) -> Void) {
        if let s = SnapshotWidget.ler() { completion(EntradaPrumo(date: Date(), snapshot: s, temDados: true)) }
        else { completion(EntradaPrumo(date: Date(), snapshot: .exemplo, temDados: context.isPreview)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaPrumo>) -> Void) {
        let s = SnapshotWidget.ler()
        let entrada = EntradaPrumo(date: Date(), snapshot: s ?? .exemplo, temDados: s != nil)
        // O app pede atualização a cada mudança; isto é só uma garantia.
        completion(Timeline(entries: [entrada], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

private extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

struct VistaPrumoWidget: View {
    @Environment(\.widgetFamily) private var familia
    let entrada: EntradaPrumo

    private let limao = Color(hex: "D2FD59")
    private let coral = Color(hex: "FF6B5E")
    private let apagado = Color.white.opacity(0.56)

    private func v(_ c: Int, compacto: Bool = false) -> String {
        if entrada.snapshot.ocultarValores { return "R$ ••••" }
        return compacto ? Dinheiro.formatarCompacto(c) : Dinheiro.formatar(c)
    }

    var body: some View {
        if !entrada.temDados {
            Text("Abra o Perity para ver seu resumo").font(.caption).multilineTextAlignment(.center).foregroundStyle(apagado)
        } else {
            switch familia {
            #if os(iOS)
            case .accessoryInline: inline
            case .accessoryRectangular: retangular
            #endif
            case .systemMedium: medio
            default: pequeno
            }
        }
    }

    private func rotulo(_ texto: String) -> some View {
        Text(texto)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(apagado)
            .lineLimit(1)
    }

    private func numero(_ texto: String, _ tamanho: CGFloat, cor: Color = .white) -> some View {
        Text(texto)
            .font(.system(size: tamanho, weight: .semibold).monospacedDigit())
            .tracking(-tamanho * 0.02)
            .minimumScaleFactor(0.55).lineLimit(1)
            .foregroundStyle(cor)
            .privacySensitive()
    }

    private func barra(_ progresso: Double) -> some View {
        let estourou = progresso > 1
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(estourou ? coral : limao)
                    .frame(width: max(4, g.size.width * min(1, max(0, progresso))))
            }
        }
        .frame(height: 4)
    }

    private var saldo: Int { entrada.snapshot.saldoContasCentavos ?? 0 }

    private var pequeno: some View {
        VStack(alignment: .leading, spacing: 5) {
            rotulo("Saldo em conta")
            numero(v(saldo), 24)
            Spacer(minLength: 0)
            rotulo("Gasto no mês")
            numero(v(entrada.snapshot.gastoMesCentavos, compacto: true), 15)
            barra(progresso)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medio: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                rotulo("Saldo em conta")
                numero(v(saldo), 26)
                Spacer(minLength: 0)
                rotulo("Faturas dos cartões")
                numero(v(entrada.snapshot.faturasCentavos ?? 0, compacto: true), 15)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
            VStack(alignment: .leading, spacing: 5) {
                rotulo("Gasto no mês")
                numero(v(entrada.snapshot.gastoMesCentavos), 19)
                barra(progresso)
                Spacer(minLength: 0)
                if let falta = entrada.snapshot.fixosFaltaCentavos, let pagos = entrada.snapshot.fixosPagos,
                   let total = entrada.snapshot.fixosQuantidade, total > 0 {
                    rotulo("Fixos · \(pagos) de \(total) pagos")
                    numero(falta == 0 ? "Tudo pago" : "Falta \(v(falta, compacto: true))", 15, cor: falta == 0 ? limao : .white)
                } else if let nome = entrada.snapshot.proximaFaturaNome, let d = entrada.snapshot.proximaFaturaData,
                          let c = entrada.snapshot.proximaFaturaCentavos {
                    rotulo("\(nome) · \(d.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "pt_BR"))))")
                    numero(v(c), 15)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    #if os(iOS)
    private var inline: some View {
        Text("Em conta: \(v(saldo, compacto: true))").privacySensitive()
    }

    private var retangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Perity").font(.caption2.weight(.semibold))
            Text("Em conta: \(v(saldo, compacto: true))").font(.headline).privacySensitive()
            Text("Gasto no mês: \(v(entrada.snapshot.gastoMesCentavos, compacto: true))").font(.caption2).privacySensitive()
        }
    }
    #endif

    /// Gasto até agora contra a média dos 3 meses anteriores (ou a previsão, se não houver histórico).
    private var progresso: Double {
        let ref = entrada.snapshot.mediaMensalCentavos > 0 ? entrada.snapshot.mediaMensalCentavos : max(entrada.snapshot.previsaoMesCentavos, 1)
        return Double(entrada.snapshot.gastoMesCentavos) / Double(ref)
    }
}

struct PrumoResumoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PrumoResumo", provider: ProvedorPrumo()) { entrada in
            VistaPrumoWidget(entrada: entrada)
                .containerBackground(Color.black, for: .widget)
        }
        .configurationDisplayName("Resumo do mês")
        .description("Saldo em conta, faturas, gasto do mês e fixos a pagar.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

@main
struct PrumoWidgets: WidgetBundle {
    var body: some Widget {
        PrumoResumoWidget()
    }
}
