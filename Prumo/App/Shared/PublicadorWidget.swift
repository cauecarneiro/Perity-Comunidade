import SwiftData
import WidgetKit
import PrumoCore

/// Grava o resumo que os widgets leem e pede para eles se atualizarem.
@MainActor
enum PublicadorWidget {
    static func publicar(_ ctx: ModelContext, ocultarValores: Bool, demo: Bool) {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "prumo-captura") != nil { return }
        #endif
        guard let lancs = try? ctx.fetch(FetchDescriptor<Lancamento>()),
              let contas = try? ctx.fetch(FetchDescriptor<Conta>()) else { return }
        let snap = SnapshotWidget.calcular(
            lancamentos: lancs,
            contas: contas,
            investimentos: (try? ctx.fetch(FetchDescriptor<Investimento>())) ?? [],
            emprestimos: (try? ctx.fetch(FetchDescriptor<Emprestimo>())) ?? [],
            faturas: (try? ctx.fetch(FetchDescriptor<Fatura>())) ?? [],
            fixos: (try? ctx.fetch(FetchDescriptor<Fixo>())) ?? [],
            marcas: (try? ctx.fetch(FetchDescriptor<MarcaFixo>())) ?? [],
            ocultarValores: ocultarValores, demo: demo)
        guard !contas.isEmpty else { return }
        snap.gravar()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
