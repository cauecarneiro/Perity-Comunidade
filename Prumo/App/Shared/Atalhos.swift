import AppIntents
import SwiftData
import PrumoCore

/// Chamada pelo Atalhos do iPhone a cada compra no Apple Pay (automação "Transação").
struct RegistrarCompraIntent: AppIntent {
    static let title: LocalizedStringResource = "Registrar compra"
    static let description = IntentDescription("Registra na hora um gasto do Apple Pay no Perity.")
    static let openAppWhenRun = false
    // Sem exigir desbloqueio de propósito: a automação do Apple Pay roda com o aparelho bloqueado
    // e precisa conseguir registrar a compra. Este atalho só grava; quem lê valores em voz alta exige autenticação.
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    @Parameter(title: "Valor", description: "Valor da compra, como vem da Carteira (ex.: R$ 45,90).")
    var valor: String

    @Parameter(title: "Estabelecimento", description: "Nome do comerciante.")
    var estabelecimento: String

    @Parameter(title: "Cartão", description: "Nome do cartão na Carteira.", default: "")
    var cartao: String

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar \(\.$valor) em \(\.$estabelecimento) no cartão \(\.$cartao)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let contexto = ArmazemPrumo.container.mainContext
        let r = try Carteira.registrar(contexto, valorTexto: valor, estabelecimento: estabelecimento, cartao: cartao)
        PublicadorWidget.publicar(contexto, ocultarValores: Preferencias.ocultarValores, demo: Preferencias.modoDemo)
        switch r {
        case .registrado(let titulo, let centavos):
            if Preferencias.ocultarValores { return .result(dialog: "Compra registrada.") }
            return .result(dialog: "Registrado: \(Dinheiro.formatar(-centavos)) em \(titulo).")
        case .duplicado:
            return .result(dialog: "Essa compra já tinha sido registrada.")
        case .valorInvalido(let v):
            return .result(dialog: "Não entendi o valor “\(v)”.")
        }
    }
}

/// "Quanto gastei este mês?" pela Siri ou pelo Atalhos.
struct ResumoDoMesIntent: AppIntent {
    static let title: LocalizedStringResource = "Resumo do mês"
    static let description = IntentDescription("Diz quanto você gastou e recebeu neste mês.")
    static let openAppWhenRun = false
    /// Fala valores em voz alta: só com o aparelho desbloqueado (ou autenticado).
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Se o usuário escondeu os valores do Início, o atalho também não fala valores.
        if Preferencias.ocultarValores {
            return .result(dialog: "Os valores estão ocultos nos ajustes do Perity. Abra o app para ver o resumo do mês.")
        }
        let ctx = ArmazemPrumo.container.mainContext
        let lancs = try ctx.fetch(FetchDescriptor<Lancamento>())
        let contas = try ctx.fetch(FetchDescriptor<Conta>())
        let hoje = Date()
        let r = Analise.resumoDoMes(hoje, lancamentos: lancs, contas: contas, hoje: hoje)
        let p = Analise.previsaoDoMes(lancamentos: lancs, contas: contas, hoje: hoje)
        guard r.quantidade > 0 else { return .result(dialog: "Ainda não há lançamentos neste mês.") }
        var texto = "Neste mês você gastou \(Dinheiro.formatar(r.despesasCentavos)) e recebeu \(Dinheiro.formatar(r.receitasCentavos))."
        if let top = r.porCategoria.first { texto += " A maior categoria é \(top.info.nome), com \(Dinheiro.formatar(top.centavos))." }
        if p.diasRestantes > 0 { texto += " A previsão para o fim do mês é \(Dinheiro.formatar(p.projetadoCentavos))." }
        return .result(dialog: IntentDialog(stringLiteral: texto))
    }
}

struct PrumoAtalhos: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ResumoDoMesIntent(),
            phrases: ["Quanto gastei este mês no \(.applicationName)", "Resumo do mês no \(.applicationName)"],
            shortTitle: "Resumo do mês",
            systemImageName: "chart.pie.fill"
        )
        AppShortcut(
            intent: RegistrarCompraIntent(),
            phrases: ["Registrar compra no \(.applicationName)"],
            shortTitle: "Registrar compra",
            systemImageName: "plus.circle.fill"
        )
    }
}
