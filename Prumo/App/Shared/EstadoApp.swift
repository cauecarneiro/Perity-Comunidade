import Observation
#if os(macOS)
import AppKit
#endif
import SwiftData
import SwiftUI
import PrumoCore

/// Captura de telas (`-prumo-captura <pasta>`): só existe em build de desenvolvimento.
/// No Release é uma constante falsa, então nenhum argumento de linha de comando muda o comportamento do app.
enum ModoCaptura {
    static var ativo: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "prumo-captura") != nil
        #else
        return false
        #endif
    }
}

/// Banco de dados único do app. As ações do Atalhos (App Intents) usam o mesmo container.
@MainActor
enum ArmazemPrumo {
    /// Preenchido se o banco do disco não pôde ser aberto e o app caiu para a memória.
    static private(set) var aviso: String?

    static let container: ModelContainer = {
        do {
            // Em captura de telas (-prumo-captura <pasta>) nada é gravado em disco.
            if ModoCaptura.ativo {
                return try EsquemaPrumo.container(emMemoria: true)
            }
            return try EsquemaPrumo.container()
        } catch {
            aviso = "Não consegui abrir o banco de dados (\(error.localizedDescription)). Os dados desta sessão não serão salvos."
            // Último recurso: memória, para o app abrir e mostrar o aviso em vez de fechar.
            return try! EsquemaPrumo.container(emMemoria: true)
        }
    }()
}

@MainActor
@Observable
final class EstadoApp {
    enum Atualizacao: Equatable {
        case ociosa
        case atualizando
        case concluida(texto: String, quando: Date, comErro: Bool)
    }

    let container: ModelContainer

    var atualizacao: Atualizacao = .ociosa
    var ultimaAtualizacao: Date? = Preferencias.ultimaSincronizacao
    var ultimoResumo: ResumoSincronizacao?

    /// Páginas com os valores ocultos. O olho é independente em cada uma (Início, Investimentos, Fixos).
    private(set) var paginasOcultas: Set<Secao>

    /// Os valores do Início (e dos seus detalhes) estão ocultos. É o que o widget segue.
    var ocultarValores: Bool { paginasOcultas.contains(.inicio) }

    func oculta(_ secao: Secao) -> Bool { paginasOcultas.contains(secao) }

    func definirOcultar(_ oculto: Bool, em secao: Secao) {
        guard oculta(secao) != oculto else { return }
        if oculto { paginasOcultas.insert(secao) } else { paginasOcultas.remove(secao) }
        Preferencias.definirOcultarValores(oculto, pagina: secao.rawValue)
        if secao == .inicio { publicarWidgets() }
    }

    func alternarOcultar(_ secao: Secao) { definirOcultar(!oculta(secao), em: secao) }

    /// Oculta ou mostra tudo de uma vez (ajustes, captura de telas).
    func definirOcultarTudo(_ oculto: Bool) { for s in Secao.allCases { definirOcultar(oculto, em: s) } }
    var modoDemo: Bool { didSet { Preferencias.modoDemo = modoDemo } }
    var buscaBancos: Bool { didSet { Preferencias.dispositivoBuscaBancos = buscaBancos } }
    var temCredenciais: Bool

    /// Aba atual do iPhone. No Mac, as áreas viram páginas (`pagina`).
    var secao: Secao = .inicio {
        didSet {
            guard secao != oldValue else { return }
            selecoes += 1
            if pagina.secao != secao { pagina = Pagina(secao) }
        }
    }
    /// Sobe a cada troca de aba: é o sinal para a tela que entra repetir a animação de entrada.
    var selecoes = 0
    /// Página aberta no Mac (barra lateral).
    var pagina: Pagina = .visaoGeral
    /// Filtro pedido por outra página do Mac ("ver os lançamentos de Gasolina").
    var filtroDoMac = FiltroLancamentos()
    /// A abertura animada ainda está na tela.
    var abrindo: Bool
    /// Esta execução mostra a abertura animada (não mostra em captura de telas).
    let comAbertura: Bool
    /// CDI de cada mês (Banco Central), para comparar com os investimentos.
    var cdi: TabelaCDI? = CDI.guardado()
    var avisoArmazenamento: String?

    private var agendador: Task<Void, Never>?

    init(container: ModelContainer? = nil) {
        self.container = container ?? ArmazemPrumo.container
        paginasOcultas = Set(Secao.allCases.filter { Preferencias.ocultarValores(pagina: $0.rawValue) })
        modoDemo = Preferencias.modoDemo
        buscaBancos = Preferencias.dispositivoBuscaBancos
        temCredenciais = Cofre.credenciaisPluggy() != nil
        avisoArmazenamento = ArmazemPrumo.aviso
        // Em captura de telas e quando pedido (-prumo-abertura NO), o app abre direto.
        let args = UserDefaults.standard
        comAbertura = !ModoCaptura.ativo && args.string(forKey: "prumo-abertura") != "NO"
        abrindo = comAbertura
    }

    /// Vai para uma área do app (aba no iPhone, página no Mac).
    func ir(_ s: Secao) {
        pagina = Pagina(s)
        secao = s
    }

    /// CDI usado nas telas: o do Banco Central; na demonstração sem internet, um de exemplo.
    var cdiEmUso: TabelaCDI? {
        cdi ?? (modoDemo ? DadosDemo.cdiDeExemplo() : nil)
    }

    /// Vai para a lista de lançamentos já filtrada (Mac).
    func abrirLancamentos(_ filtro: FiltroLancamentos) {
        filtroDoMac = filtro
        pagina = .lancamentos
    }

    var contexto: ModelContext { container.mainContext }

    // MARK: Início

    func iniciar() {
        #if DEBUG
        // Só em desenvolvimento: abre direto nos dados de exemplo e na seção pedida (usado para tirar fotos das telas).
        let args = UserDefaults.standard
        if args.bool(forKey: "prumo-demo") {
            if !modoDemo || !DadosDemo.existe(contexto) { ativarDemo() }
        }
        if let nome = args.string(forKey: "prumo-secao"), let s = Secao(rawValue: nome) { secao = s }
        if args.bool(forKey: "prumo-ocultar") { definirOcultarTudo(true) }
        if args.bool(forKey: "prumo-passeio") { passear() }
        // Teste da abertura: ocupa o app por N milissegundos logo no começo, como uma conta pesada faria.
        let travar = args.integer(forKey: "prumo-travar")
        if travar > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let fim = CFAbsoluteTimeGetCurrent() + Double(travar) / 1000
                while CFAbsoluteTimeGetCurrent() < fim {}
            }
        }
        if args.bool(forKey: "prumo-medir") {
            Task {
                try? await Task.sleep(nanoseconds: 9_000_000_000)
                for (nome, ms) in Diagnostico.tempos { print("TEMPO|\(nome)|\(Int(ms)) ms") }
                fflush(stdout)
                #if os(macOS)
                NSApplication.shared.terminate(nil)
                #endif
            }
        }
        #endif
        if modoDemo && !DadosDemo.existe(contexto) {
            try? DadosDemo.popular(contexto)
        }
        // A manutenção espera a abertura terminar: nada disso precisa estar pronto no primeiro segundo,
        // e rodar junto da abertura fazia a animação travar.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            self?.manutencaoDeAbertura()
        }
        agendador?.cancel()
        agendador = Task { [weak self] in
            // A primeira busca nos bancos também espera a abertura terminar.
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            while !Task.isCancelled {
                await self?.atualizarSeNecessario()
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            }
        }
    }

    private func manutencaoDeAbertura() {
        _ = Diagnostico.medir("higiene") { try? Higiene.deduplicar(contexto) }
        _ = Diagnostico.medir("conciliar") { try? Conciliador.conciliar(contexto) }
        // As categorias ficaram mais detalhadas: passa uma vez pelos lançamentos antigos.
        if Preferencias.versaoCategorias < Recategorizador.versao, (try? Recategorizador.refinar(contexto)) != nil {
            Preferencias.versaoCategorias = Recategorizador.versao
        }
        Diagnostico.medir("varrer fixos") { varrerFixos() }
        Diagnostico.medir("widgets") { publicarWidgets() }
        buscarCDI()
    }

    /// Olha todo o extrato guardado: o que se repete todo mês vira fixo sozinho, e os fixos que já existem
    /// ganham a conta de onde saem e o dia em que costumam ser cobrados. Nunca mexe no que você desativou.
    func varrerFixos() {
        // Em captura de telas a lista é a da demonstração, do jeito que está.
        guard !ModoCaptura.ativo else { return }
        let ctx = contexto
        guard let modelos = try? ctx.fetch(FetchDescriptor<Lancamento>()), !modelos.isEmpty,
              let contas = try? ctx.fetch(FetchDescriptor<Conta>()),
              let fixos = try? ctx.fetch(FetchDescriptor<Fixo>()) else { return }
        let hoje = Date()
        let leves = LancamentoLeve.copiar(modelos, hoje: hoje)
        let recorrentes = Analise.recorrentes(lancamentos: leves, contas: contas, hoje: hoje, meses: 13)
        let r = Fixos.varrer(recorrentes: recorrentes, fixos: fixos, contas: contas, lancamentos: leves, hoje: hoje)
        var ordem = (fixos.map(\.ordem).max() ?? -1) + 1
        for f in r.novos {
            f.ordem = ordem
            ordem += 1
            f.demo = modoDemo
            ctx.insert(f)
        }
        for e in r.enriquecidos {
            guard let f = fixos.first(where: { $0.uid == e.uid }) else { continue }
            if f.contaID == nil, let c = e.contaID { f.contaID = c }
            if f.diaTipico == nil, let d = e.diaTipico { f.diaTipico = d }
        }
        if !r.novos.isEmpty || !r.enriquecidos.isEmpty { try? ctx.save() }
    }

    /// Consulta pública ao Banco Central (não envia nada seu). Em captura de telas não usa a rede.
    func buscarCDI() {
        guard !ModoCaptura.ativo else { return }
        Task { [weak self] in
            let tabela = await CDI.atualizar()
            if let tabela, tabela != self?.cdi { self?.cdi = tabela }
        }
    }

    #if DEBUG
    /// Só em desenvolvimento (`-prumo-passeio YES`): troca de aba sozinho algumas vezes e anota quantas vezes
    /// as contas foram refeitas. Serve para gravar a animação de entrada e conferir que navegar não recalcula.
    private func passear() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let antes = Diagnostico.resumo
            for s in [Secao.investimentos, .inicio, .fixos, .investimentos, .inicio] {
                self?.secao = s
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            let texto = "antes: \(antes)\ndepois: \(Diagnostico.resumo)\n"
            let pasta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            try? texto.write(to: (pasta ?? FileManager.default.temporaryDirectory).appendingPathComponent("passeio.txt"),
                             atomically: true, encoding: .utf8)
        }
    }
    #endif

    func parar() {
        agendador?.cancel()
        agendador = nil
    }

    func publicarWidgets() {
        PublicadorWidget.publicar(contexto, ocultarValores: ocultarValores, demo: modoDemo)
    }

    // MARK: Atualização com os bancos

    func atualizarSeNecessario() async {
        guard buscaBancos, temCredenciais, !modoDemo else { return }
        let intervalo = TimeInterval(Preferencias.intervaloSyncMinutos * 60)
        if let u = Preferencias.ultimaSincronizacao, Date().timeIntervalSince(u) < intervalo { return }
        await atualizar()
    }

    func atualizar() async {
        guard atualizacao != .atualizando else { return }
        guard let cred = Cofre.credenciaisPluggy() else {
            atualizacao = .concluida(texto: "Falta o Client ID e o Secret da Pluggy", quando: Date(), comErro: true)
            return
        }
        atualizacao = .atualizando
        let motor = MotorDeSincronizacao(contexto: contexto, cliente: PluggyClient(credenciais: cred))
        let r = await motor.sincronizarTudo()
        ultimoResumo = r
        let agora = Date()
        if !r.teveErro || r.lancamentosNovos > 0 {
            Preferencias.ultimaSincronizacao = agora
            ultimaAtualizacao = agora
        }
        atualizacao = .concluida(texto: r.textoCurto, quando: agora, comErro: r.teveErro)
        if r.lancamentosNovos > 0 { varrerFixos() }
        publicarWidgets()
    }

    // MARK: Demonstração

    func ativarDemo() {
        do {
            try DadosDemo.popular(contexto)
            modoDemo = true
            publicarWidgets()
        } catch {
            avisoArmazenamento = "Não consegui criar os dados de exemplo: \(error.localizedDescription)"
        }
    }

    func desativarDemo() {
        try? DadosDemo.limpar(contexto)
        modoDemo = false
    }

    // MARK: Credenciais

    func salvarCredenciais(clientID: String, clientSecret: String) {
        let c = PluggyCredenciais(clientID: clientID, clientSecret: clientSecret)
        guard c.estaCompleta else { return }
        let ok = Cofre.salvar(c.clientID, para: .pluggyClientID) && Cofre.salvar(c.clientSecret, para: .pluggyClientSecret)
        temCredenciais = ok
        if !ok {
            avisoArmazenamento = "Não consegui guardar a credencial no Keychain deste aparelho. Confira se o app está assinado e tente de novo."
        }
    }

    func apagarCredenciais() {
        Cofre.apagar(.pluggyClientID)
        Cofre.apagar(.pluggyClientSecret)
        temCredenciais = false
        buscaBancos = false
    }
}
