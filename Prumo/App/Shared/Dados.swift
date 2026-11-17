import SwiftData
import SwiftUI
import PrumoCore

// Os números do app são calculados em um lugar só, acima das telas, e só quando os dados mudam.
// As telas apenas leem o resultado. Antes cada tela refazia todas as contas ao abrir, e era isso
// que deixava a navegação travada.
//
// São três etapas, cada uma com as suas consultas, para uma mudança pequena não refazer tudo:
// marcar um fixo como pago só refaz a etapa 3.
//   1. `ProvedorDoMes`    lançamentos e contas (a parte pesada: resumo, previsão, ritmo, destaques)
//   2. `ProvedorDaAgenda` faturas, empréstimos, conexões e investimentos (vencimentos, avisos, CDI)
//   3. `ProvedorDosFixos` fixos e marcações

struct GrupoBanco: Identifiable {
    let nome: String
    let contas: [Conta]
    let totalCentavos: Int
    var id: String { nome }
}

// MARK: - Etapa 1: o mês

struct BaseDoMes {
    /// Sobe a cada cálculo: as etapas seguintes sabem se a base mudou.
    var geracao = 0
    var hoje: Date
    /// Cópia leve dos lançamentos (ler o banco a cada conta é o que custava caro).
    var lancamentos: [LancamentoLeve]
    var contas: [Conta]
    var bancos: [GrupoBanco]
    var saldoCentavos: Int
    var quantasContas: Int
    var cartoes: [Conta]
    var faturasCentavos: Int
    var limiteLivreCentavos: Int
    var limiteTotalCentavos: Int
    var proximoVencimentoFatura: Date?
    var mes: ResumoPeriodo
    var previsao: Previsao
    var ritmo: [PontoRitmo]
    var serie: [PontoMensal]
    var comparacaoRitmo: Double?
    var recorrentes: [Recorrente]
    var destaques: [Destaque]
    var areas: [GastoArea]
    var recentes: [Lancamento]

    @MainActor
    static func calcular(lancamentos modelos: [Lancamento], contas: [Conta], hoje: Date = Date()) -> BaseDoMes {
        let lancamentos = LancamentoLeve.copiar(modelos, hoje: hoje)
        let bancarias = contas.filter { !$0.tipo.ehCartao && !$0.arquivada }
        let cartoes = contas.filter { $0.tipo.ehCartao && !$0.arquivada }.sorted { $0.saldoCentavos > $1.saldoCentavos }
        let porBanco: [String: [Conta]] = Dictionary(grouping: bancarias) { $0.instituicao.isEmpty ? "Outras contas" : $0.instituicao }
        var grupos: [GrupoBanco] = []
        for (nome, itens) in porBanco {
            let ordenadas: [Conta] = itens.sorted { $0.saldoCentavos > $1.saldoCentavos }
            let total: Int = itens.filter(\.contaNoPatrimonio).reduce(0) { $0 + $1.saldoCentavos }
            grupos.append(GrupoBanco(nome: nome, contas: ordenadas, totalCentavos: total))
        }
        grupos.sort { a, b in a.totalCentavos != b.totalCentavos ? a.totalCentavos > b.totalCentavos : a.nome < b.nome }

        let mes = Analise.resumoDoMes(hoje, lancamentos: lancamentos, contas: contas, hoje: hoje)
        let ritmo = Analise.ritmoDoMes(lancamentos: lancamentos, contas: contas, hoje: hoje)
        var comparacao: Double?
        let diaAtual = Datas.calendario.component(.day, from: hoje)
        if let hojeAnterior = ritmo.first(where: { $0.dia == diaAtual })?.anteriorCentavos, hojeAnterior > 0 {
            comparacao = Double(mes.despesasCentavos - hojeAnterior) / Double(hojeAnterior)
        }
        // Os últimos lançamentos: ordena a cópia leve e só no fim busca os modelos (a tela mostra o modelo).
        let limiteRecentes = Datas.somar(dias: 1, a: hoje)
        let recentes = lancamentos.indices
            .filter { lancamentos[$0].conciliadoComID == nil && !lancamentos[$0].ignorado && lancamentos[$0].data <= limiteRecentes }
            .sorted { (lancamentos[$0].data, lancamentos[$0].criadoEm) > (lancamentos[$1].data, lancamentos[$1].criadoEm) }
            .prefix(12)
            .map { modelos[$0] }
        let comLimite = cartoes.filter { ($0.limiteCentavos ?? 0) > 0 }
        let inicioHoje = Datas.inicioDoDia(hoje)

        MemoriaGeracoes.valor += 1
        return BaseDoMes(
            geracao: MemoriaGeracoes.valor, hoje: hoje, lancamentos: lancamentos, contas: contas,
            bancos: grupos,
            saldoCentavos: bancarias.filter(\.contaNoPatrimonio).reduce(0) { $0 + $1.saldoCentavos },
            quantasContas: bancarias.count,
            cartoes: cartoes,
            faturasCentavos: cartoes.reduce(0) { $0 + max($1.saldoCentavos, 0) },
            limiteLivreCentavos: comLimite.reduce(0) { $0 + max($1.disponivelCentavos ?? 0, 0) },
            limiteTotalCentavos: comLimite.reduce(0) { $0 + ($1.limiteCentavos ?? 0) },
            proximoVencimentoFatura: cartoes.compactMap(\.vencimentoFatura).filter { $0 >= inicioHoje }.min(),
            mes: mes,
            previsao: Analise.previsaoDoMes(lancamentos: lancamentos, contas: contas, hoje: hoje),
            ritmo: ritmo,
            serie: Analise.serieMensal(lancamentos: lancamentos, contas: contas, meses: 6, ate: hoje),
            comparacaoRitmo: comparacao,
            recorrentes: Analise.recorrentes(lancamentos: lancamentos, contas: contas, hoje: hoje),
            destaques: Analise.destaquesDoMes(lancamentos: lancamentos, contas: contas, hoje: hoje),
            areas: Analise.porArea(mes.porCategoria),
            recentes: Array(recentes))
    }
}

// MARK: - Etapa 2: agenda e investimentos

struct PainelInvestimentos {
    var ativos: [Investimento]
    var totalCentavos: Int
    var rendimento: RendimentoCarteira
    var fatias: [FatiaAlocacao]
    var evolucao: [PontoEvolucao]
    var vencimentos: [Investimento]
    /// O mês que fechou, comparado com o CDI.
    var fechamento: FechamentoInvestimentos

    static func calcular(investimentos: [Investimento], fotos: [FotoPatrimonio], cdi: TabelaCDI?, hoje: Date = Date()) -> PainelInvestimentos {
        let ativos = investimentos.filter(\.ativo).sorted { $0.saldoCentavos > $1.saldoCentavos }
        let serie = fotos.suffix(120).map { PontoEvolucao(dia: $0.dia, centavos: $0.investidoCentavos) }
        let temSerie = serie.count > 2 && serie.contains { $0.centavos > 0 }
        let inicioHoje = Datas.inicioDoDia(hoje)
        return PainelInvestimentos(
            ativos: ativos,
            totalCentavos: ativos.reduce(0) { $0 + $1.saldoCentavos },
            rendimento: Analise.rendimentoCarteira(ativos),
            fatias: Analise.alocacao(ativos),
            evolucao: temSerie ? serie : [],
            vencimentos: ativos.filter { ($0.vencimento ?? .distantPast) >= inicioHoje }
                .sorted { ($0.vencimento ?? .distantFuture) < ($1.vencimento ?? .distantFuture) },
            fechamento: Analise.fechamentoInvestimentos(ativos, cdi: cdi, hoje: hoje))
    }
}

struct Agenda {
    var emprestimos: [Emprestimo]
    var conexoes: [Conexao]
    var vencimentos: [Vencimento]
    var avisos: [Insight]
    var investimentos: PainelInvestimentos
}

// MARK: - O que as telas leem

/// Tudo que o Início e as telas de detalhe mostram.
struct PainelInicio {
    var hoje: Date
    var lancamentos: [LancamentoLeve]
    var contas: [Conta]
    // Contas
    var bancos: [GrupoBanco]
    var saldoCentavos: Int
    var quantasContas: Int
    // Cartões
    var cartoes: [Conta]
    var faturasCentavos: Int
    var limiteLivreCentavos: Int
    var limiteTotalCentavos: Int
    var proximoVencimentoFatura: Date?
    var emprestimos: [Emprestimo]
    // Mês
    var mes: ResumoPeriodo
    var previsao: Previsao
    var ritmo: [PontoRitmo]
    var serie: [PontoMensal]
    var comparacaoRitmo: Double?
    var destaques: [Destaque]
    var areas: [GastoArea]
    var recorrentes: [Recorrente]
    // Agenda
    var fixos: ResumoFixos
    var vencimentos: [Vencimento]
    var avisos: [Insight]
    var recentes: [Lancamento]
    var conexoes: [Conexao]

    var nomeDoMes: String { hoje.formatted(.dateTime.month(.wide).locale(Locale(identifier: "pt_BR"))) }

    init(base b: BaseDoMes, agenda a: Agenda, fixos: ResumoFixos) {
        hoje = b.hoje; lancamentos = b.lancamentos; contas = b.contas
        bancos = b.bancos; saldoCentavos = b.saldoCentavos; quantasContas = b.quantasContas
        cartoes = b.cartoes; faturasCentavos = b.faturasCentavos
        limiteLivreCentavos = b.limiteLivreCentavos; limiteTotalCentavos = b.limiteTotalCentavos
        proximoVencimentoFatura = b.proximoVencimentoFatura; emprestimos = a.emprestimos
        mes = b.mes; previsao = b.previsao; ritmo = b.ritmo; serie = b.serie; comparacaoRitmo = b.comparacaoRitmo
        destaques = b.destaques; areas = b.areas; recorrentes = b.recorrentes
        self.fixos = fixos; vencimentos = a.vencimentos; avisos = a.avisos; recentes = b.recentes; conexoes = a.conexoes
    }
}

private struct BaseDoMesChave: EnvironmentKey { static let defaultValue: BaseDoMes? = nil }
private struct AgendaChave: EnvironmentKey { static let defaultValue: Agenda? = nil }
private struct PainelChave: EnvironmentKey { static let defaultValue: PainelInicio? = nil }
private struct PainelInvestimentosChave: EnvironmentKey { static let defaultValue: PainelInvestimentos? = nil }

extension EnvironmentValues {
    fileprivate var baseDoMes: BaseDoMes? {
        get { self[BaseDoMesChave.self] }
        set { self[BaseDoMesChave.self] = newValue }
    }
    fileprivate var agenda: Agenda? {
        get { self[AgendaChave.self] }
        set { self[AgendaChave.self] = newValue }
    }
    var painel: PainelInicio? {
        get { self[PainelChave.self] }
        set { self[PainelChave.self] = newValue }
    }
    var painelInvestimentos: PainelInvestimentos? {
        get { self[PainelInvestimentosChave.self] }
        set { self[PainelInvestimentosChave.self] = newValue }
    }
}

// MARK: - Provedores

#if DEBUG
/// Só em desenvolvimento: conta quantas vezes cada etapa foi refeita, para conferir que navegar não recalcula nada.
@MainActor
enum Diagnostico {
    static var mes = 0
    static var agenda = 0
    static var fixos = 0
    static var resumo: String { "mes=\(mes) agenda=\(agenda) fixos=\(fixos)" }
    static var tempos: [(String, Double)] = []
    static let relogio = CFAbsoluteTimeGetCurrent()
    static func anotar(_ texto: String) { tempos.append(("\(Int((CFAbsoluteTimeGetCurrent() - relogio) * 1000)) ms " + texto, 0)) }

    /// Mede quanto um trecho leva (em milissegundos) e guarda para `-prumo-medir`.
    static func medir<T>(_ nome: String, _ bloco: () -> T) -> T {
        let inicio = CFAbsoluteTimeGetCurrent()
        let r = bloco()
        tempos.append((nome, (CFAbsoluteTimeGetCurrent() - inicio) * 1000))
        return r
    }
}
#else
@MainActor
enum Diagnostico {
    static func medir<T>(_ nome: String, _ bloco: () -> T) -> T { bloco() }
}
#endif

/// Guarda o último resultado de uma etapa e a "chave" dos dados que o produziram. Se a tela de cima se
/// redesenha sem que os dados mudem (a abertura saindo, a janela ganhando foco), o resultado é reaproveitado.
final class Memoria<Valor> {
    var chave: [Int] = []
    var valor: Valor?

    func valor(para chave: [Int], calcular: () -> Valor) -> Valor {
        if chave == self.chave, let v = valor { return v }
        let v = calcular()
        self.chave = chave
        valor = v
        return v
    }
}

/// Contador das gerações da base (ver `BaseDoMes.geracao`). Só é usado na linha principal.
fileprivate enum MemoriaGeracoes { nonisolated(unsafe) static var valor = 0 }

/// Identifica o resultado de uma consulta: muda quando o SwiftData entrega uma lista nova.
/// (Duas listas vivas ao mesmo tempo nunca dividem o mesmo endereço.)
func marcaDaLista<T>(_ lista: [T]) -> Int {
    lista.withUnsafeBufferPointer { Int(bitPattern: $0.baseAddress) } &* 31 &+ lista.count
}

private struct ProvedorDoMes: ViewModifier {
    @Query private var lancamentos: [Lancamento]
    @Query(sort: \Conta.ordem) private var contas: [Conta]
    // Ao voltar para o app, confere: o dia pode ter virado.
    @Environment(\.scenePhase) private var fase
    @State private var memoria = Memoria<BaseDoMes>()

    func body(content: Content) -> some View {
        let _ = fase
        let dia = Int(Datas.inicioDoDia(Date()).timeIntervalSince1970)
        let chave = [marcaDaLista(lancamentos), marcaDaLista(contas), dia]
        content.environment(\.baseDoMes, memoria.valor(para: chave) {
            #if DEBUG
            Diagnostico.mes += 1
            #endif
            return Diagnostico.medir("etapa mês (\(lancamentos.count) lançamentos)") {
                BaseDoMes.calcular(lancamentos: lancamentos, contas: contas)
            }
        })
    }
}

private struct ProvedorDaAgenda: ViewModifier {
    @Environment(EstadoApp.self) private var estado
    @Environment(\.baseDoMes) private var base
    @Query private var investimentos: [Investimento]
    @Query private var emprestimos: [Emprestimo]
    @Query private var faturas: [Fatura]
    @Query private var conexoes: [Conexao]
    @Query(sort: \FotoPatrimonio.dia) private var fotos: [FotoPatrimonio]
    @State private var memoria = Memoria<Agenda>()

    func body(content: Content) -> some View {
        // Sem a memória, a agenda era refeita a cada redesenho da raiz (a abertura saindo, a janela ganhando foco),
        // bem no instante em que a entrada dos blocos começa.
        content.environment(\.agenda, base.map { b in
            var h = Hasher()
            h.combine(estado.cdiEmUso?.buscadoEm)
            h.combine(estado.cdiEmUso?.porMes.count ?? 0)
            h.combine(estado.ultimaAtualizacao)
            let chave = [b.geracao, marcaDaLista(investimentos), marcaDaLista(emprestimos), marcaDaLista(faturas),
                         marcaDaLista(conexoes), marcaDaLista(fotos), h.finalize()]
            return memoria.valor(para: chave) {
                #if DEBUG
                Diagnostico.agenda += 1
                #endif
                return Diagnostico.medir("etapa agenda") { calcular(b) }
            }
        })
    }

    private func calcular(_ b: BaseDoMes) -> Agenda {
        let painel = PainelInvestimentos.calcular(investimentos: investimentos, fotos: fotos, cdi: estado.cdiEmUso, hoje: b.hoje)
        let vencimentos = Analise.proximosVencimentos(contas: b.contas, faturas: faturas, recorrentes: b.recorrentes,
                                                      emprestimos: emprestimos, hoje: b.hoje, dias: 14)
        // Sem orçamento por categoria: essa parte saiu do app, então os avisos dela também.
        let avisos = Analise.insights(lancamentos: b.lancamentos, contas: b.contas, investimentos: investimentos,
                                      orcamentos: [], recorrentes: b.recorrentes, vencimentos: vencimentos,
                                      conexoes: conexoes, ultimaAtualizacao: estado.ultimaAtualizacao,
                                      fechamento: painel.ativos.isEmpty ? nil : painel.fechamento, hoje: b.hoje)
        return Agenda(emprestimos: emprestimos, conexoes: conexoes, vencimentos: vencimentos, avisos: avisos, investimentos: painel)
    }
}

private struct ProvedorDosFixos: ViewModifier {
    @Environment(\.baseDoMes) private var base
    @Environment(\.agenda) private var agenda
    @Query private var fixos: [Fixo]
    @Query private var marcas: [MarcaFixo]
    // As faturas dizem em que dia um fixo no cartão é debitado. São poucas linhas.
    @Query private var faturas: [Fatura]
    @State private var memoria = Memoria<ResumoFixos>()

    func body(content: Content) -> some View {
        content
            .environment(\.painel, painel)
            .environment(\.painelInvestimentos, agenda?.investimentos)
            .environment(\.fixosDoApp, FixosDoApp(fixos: fixos, marcas: marcas, faturas: faturas))
    }

    private var painel: PainelInicio? {
        guard let b = base, let a = agenda else { return nil }
        // Fixos e marcações são poucos: a chave olha o conteúdo, para uma edição nunca ficar de fora.
        var h = Hasher()
        for f in fixos {
            h.combine(f.uid); h.combine(f.valorCentavos); h.combine(f.ativo); h.combine(f.padrao); h.combine(f.acumula)
            h.combine(f.categoriaChave); h.combine(f.formaRaw); h.combine(f.contaID); h.combine(f.diaTipico); h.combine(f.automatico)
        }
        for m in marcas { h.combine(m.fixoUID); h.combine(m.mes); h.combine(m.pago) }
        let resumo = memoria.valor(para: [b.geracao, marcaDaLista(faturas), h.finalize()]) {
            #if DEBUG
            Diagnostico.fixos += 1
            #endif
            return Diagnostico.medir("etapa fixos") {
                Fixos.resumo(Fixos.situacao(fixos: fixos, marcas: marcas, lancamentos: b.lancamentos, mes: b.hoje,
                                            contas: b.contas, faturas: faturas, hoje: b.hoje))
            }
        }
        return PainelInicio(base: b, agenda: a, fixos: resumo)
    }
}

// MARK: - Conferência de categorias

/// As lojas dos últimos meses e onde caíram. Só é calculada quando uma tela pede (`lojas`), nunca na abertura,
/// e fica guardada até os lançamentos ou as regras mudarem.
struct ConferenciaDoApp {
    fileprivate var chave: [Int] = []
    fileprivate var memoria: Memoria<[LojaConferida]>?
    fileprivate var calcular: () -> [LojaConferida] = { [] }

    /// Muda quando o resultado precisa ser refeito (as telas usam como `id` da tarefa que lê `lojas`).
    var versao: Int { chave.hashValue }

    @MainActor var lojas: [LojaConferida] {
        guard let memoria else { return [] }
        return memoria.valor(para: chave) { Diagnostico.medir("etapa conferência") { calcular() } }
    }
}

private struct ConferenciaChave: EnvironmentKey { static let defaultValue = ConferenciaDoApp() }

extension EnvironmentValues {
    var conferencia: ConferenciaDoApp {
        get { self[ConferenciaChave.self] }
        set { self[ConferenciaChave.self] = newValue }
    }
}

private struct ProvedorDaConferencia: ViewModifier {
    @Environment(\.baseDoMes) private var base
    @Query private var regras: [Regra]
    @State private var memoria = Memoria<[LojaConferida]>()

    func body(content: Content) -> some View {
        content.environment(\.conferencia, conferencia)
    }

    private var conferencia: ConferenciaDoApp {
        guard let b = base else { return ConferenciaDoApp() }
        let regras = self.regras
        return ConferenciaDoApp(chave: [b.geracao, marcaDaLista(regras)], memoria: memoria) {
            Analise.conferenciaCategorias(lancamentos: b.lancamentos, contas: b.contas, regras: regras, hoje: b.hoje)
        }
    }
}

/// A lista de fixos e as marcações, lidas uma vez (a tela de Fixos usa as mesmas).
struct FixosDoApp {
    var fixos: [Fixo] = []
    var marcas: [MarcaFixo] = []
    var faturas: [Fatura] = []
}

private struct FixosDoAppChave: EnvironmentKey { static let defaultValue = FixosDoApp() }

extension EnvironmentValues {
    var fixosDoApp: FixosDoApp {
        get { self[FixosDoAppChave.self] }
        set { self[FixosDoAppChave.self] = newValue }
    }
}

extension View {
    /// Põe os números do app à disposição de todas as telas abaixo. Usar uma vez, na raiz.
    func dadosDoPerity() -> some View {
        modifier(ProvedorDosFixos()).modifier(ProvedorDaConferencia()).modifier(ProvedorDaAgenda()).modifier(ProvedorDoMes())
    }
}

// MARK: - Leitura nas telas

/// Entrega o painel já calculado para quem for desenhar. Não consulta nem calcula nada.
struct ComPainel<Conteudo: View>: View {
    @Environment(\.painel) private var painel
    @ViewBuilder var conteudo: (PainelInicio) -> Conteudo

    var body: some View {
        if let painel { conteudo(painel) }
    }
}

struct ComInvestimentos<Conteudo: View>: View {
    @Environment(\.painelInvestimentos) private var painel
    @ViewBuilder var conteudo: (PainelInvestimentos) -> Conteudo

    var body: some View {
        if let painel { conteudo(painel) }
    }
}
