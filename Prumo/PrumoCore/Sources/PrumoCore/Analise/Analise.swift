import Foundation
import SwiftData

// MARK: - Patrimônio

public struct ComposicaoPatrimonio: Sendable, Equatable {
    public var disponivelCentavos = 0
    public var investidoCentavos = 0
    public var faturasCentavos = 0
    public var emprestimosCentavos = 0

    public var dividasCentavos: Int { faturasCentavos + emprestimosCentavos }
    public var ativosCentavos: Int { disponivelCentavos + investidoCentavos }
    public var liquidoCentavos: Int { ativosCentavos - dividasCentavos }
}

public enum Patrimonio {
    public static func calcular(contas: [Conta], investimentos: [Investimento], emprestimos: [Emprestimo]) -> ComposicaoPatrimonio {
        var p = ComposicaoPatrimonio()
        for c in contas where !c.arquivada && c.contaNoPatrimonio {
            if c.tipo.ehCartao {
                p.faturasCentavos += max(c.saldoCentavos, 0)
            } else {
                p.disponivelCentavos += c.saldoCentavos
            }
        }
        p.investidoCentavos = investimentos.filter(\.ativo).reduce(0) { $0 + $1.saldoCentavos }
        p.emprestimosCentavos = emprestimos.reduce(0) { $0 + ($1.saldoDevedorCentavos ?? 0) }
        return p
    }

    /// Guarda (ou atualiza) a foto do dia, para o gráfico de evolução.
    public static func registrarFoto(_ contexto: ModelContext, hoje: Date = Date()) throws {
        let contas = try contexto.fetch(FetchDescriptor<Conta>())
        guard !contas.isEmpty else { return }
        let invs = try contexto.fetch(FetchDescriptor<Investimento>())
        let emps = try contexto.fetch(FetchDescriptor<Emprestimo>())
        let p = calcular(contas: contas, investimentos: invs, emprestimos: emps)
        let dia = Datas.inicioDoDia(hoje)
        let fim = Datas.somar(dias: 1, a: dia)
        let existente = try contexto.fetch(FetchDescriptor<FotoPatrimonio>(predicate: #Predicate { $0.dia >= dia && $0.dia < fim })).first
        if let f = existente {
            f.disponivelCentavos = p.disponivelCentavos
            f.investidoCentavos = p.investidoCentavos
            f.dividasCentavos = p.dividasCentavos
            f.liquidoCentavos = p.liquidoCentavos
        } else {
            contexto.insert(FotoPatrimonio(dia: dia, disponivelCentavos: p.disponivelCentavos,
                                           investidoCentavos: p.investidoCentavos, dividasCentavos: p.dividasCentavos))
        }
    }
}

// MARK: - Tipos de resultado

public struct GastoCategoria: Identifiable, Sendable, Equatable {
    public let chave: String
    public let centavos: Int
    public let quantidade: Int
    public var percentual: Double
    public var id: String { chave }
    public var info: CategoriaInfo { Categorias.info(chave) }

    public init(chave: String, centavos: Int, quantidade: Int, percentual: Double) {
        self.chave = chave
        self.centavos = centavos
        self.quantidade = quantidade
        self.percentual = percentual
    }
}

public struct ResumoPeriodo: Sendable {
    public var inicio: Date
    public var fim: Date
    public var receitasCentavos = 0
    public var despesasCentavos = 0
    public var quantidade = 0
    public var porCategoria: [GastoCategoria] = []
    public var receitasPorCategoria: [GastoCategoria] = []
    /// Despesa de cada dia (chave = início do dia).
    public var porDia: [Date: Int] = [:]

    public var saldoCentavos: Int { receitasCentavos - despesasCentavos }
    /// Quanto da renda sobrou (0...1, pode ser negativo).
    public var taxaDePoupanca: Double? {
        receitasCentavos > 0 ? Double(saldoCentavos) / Double(receitasCentavos) : nil
    }
}

public struct PontoMensal: Identifiable, Sendable, Equatable {
    public let mes: Date
    public let receitasCentavos: Int
    public let despesasCentavos: Int
    public var saldoCentavos: Int { receitasCentavos - despesasCentavos }
    public var id: Date { mes }
}

public struct Previsao: Sendable, Equatable {
    public let gastoAteHojeCentavos: Int
    public let projetadoCentavos: Int
    public let mediaDiariaCentavos: Int
    public let diasRestantes: Int
    public let mediaMensalCentavos: Int
}

/// Uma cobrança de um gasto recorrente.
public struct OcorrenciaRecorrente: Sendable, Equatable, Identifiable {
    /// "2026-10"
    public let mes: String
    public let data: Date
    public let valorCentavos: Int
    public let contaID: String
    public let externalID: String
    public var id: String { externalID }
}

public struct Recorrente: Identifiable, Sendable, Equatable {
    public let id: String
    public let nome: String
    public let categoriaChave: String
    public let valorCentavos: Int
    public let ultimaData: Date
    public let proximaData: Date
    public let ocorrencias: Int
    public let variacaoUltima: Double?
    public let ehReceita: Bool
    /// Conta de onde mais vezes saiu.
    public let contaID: String
    /// Todas as cobranças encontradas, da mais antiga para a mais nova.
    public let ocorrenciasPorMes: [OcorrenciaRecorrente]
    /// Dia do mês em que costuma cair (mediana).
    public let diaTipico: Int
    /// Valor que costuma ter (mediana).
    public let valorTipico: Int
    /// Quanto os valores oscilam em volta do típico (0 = sempre igual; 0,1 = até 10%).
    public let variacao: Double
    public var categoria: CategoriaInfo { Categorias.info(categoriaChave) }
}

public enum TipoVencimento: String, Sendable { case fatura, recorrente, emprestimo }

public struct Vencimento: Identifiable, Sendable, Equatable {
    public let id: String
    public let data: Date
    public let titulo: String
    public let subtitulo: String
    public let valorCentavos: Int
    public let tipo: TipoVencimento
    public let estimado: Bool
}

public enum EstadoOrcamento: String, Sendable { case tranquilo, atencao, estourado }

public struct ItemOrcamento: Identifiable, Sendable, Equatable {
    public let chave: String
    public let limiteCentavos: Int
    public let gastoCentavos: Int
    public var id: String { chave }

    public init(chave: String, limiteCentavos: Int, gastoCentavos: Int) {
        self.chave = chave
        self.limiteCentavos = limiteCentavos
        self.gastoCentavos = gastoCentavos
    }

    public var info: CategoriaInfo { Categorias.info(chave) }
    public var restanteCentavos: Int { limiteCentavos - gastoCentavos }
    public var percentual: Double { limiteCentavos > 0 ? Double(gastoCentavos) / Double(limiteCentavos) : 0 }
    public var estado: EstadoOrcamento {
        percentual >= 1 ? .estourado : (percentual >= 0.8 ? .atencao : .tranquilo)
    }
}

public enum SeveridadeInsight: String, Sendable { case info, positivo, atencao, alerta }

public struct Insight: Identifiable, Sendable, Equatable {
    public let id: String
    public let severidade: SeveridadeInsight
    public let icone: String
    public let titulo: String
    public let texto: String
}

public struct FatiaAlocacao: Identifiable, Sendable, Equatable {
    public let classe: ClasseAtivo
    public let centavos: Int
    public var percentual: Double
    public var id: String { classe.rawValue }
}

/// Quanto a carteira rendeu. "Desde que aplicou" vem do custo informado; "mês" e "12 meses" são
/// estimativas a partir das taxas que cada instituição informa (aportes e resgates as distorcem).
public struct RendimentoCarteira: Equatable, Sendable {
    public var saldoCentavos: Int
    public var totalInvestimentos: Int
    public var aplicadoCentavos: Int
    public var resultadoCentavos: Int
    public var resultadoPercentual: Double?
    public var mesCentavos: Int?
    public var mesPercentual: Double?
    public var mesCobertos: Int
    public var dozeMesesCentavos: Int?
    public var dozeMesesPercentual: Double?
    public var dozeMesesCobertos: Int
}

// MARK: - Análises

public enum Analise {

    // Receita/despesa de um lançamento. Em cartão, entrada é estorno (reduz a despesa).
    static func fluxo<L: LancamentoAnalisavel>(_ l: L, cartao: Bool) -> (receita: Int, despesa: Int) {
        guard l.contaParaRelatorios else { return (0, 0) }
        if cartao { return (0, -l.valorCentavos) }
        // Estorno e reembolso devolvem gasto: reduzem a despesa em vez de contar como renda.
        if l.valorCentavos > 0 && l.categoriaChave == "reembolsos" { return (0, -l.valorCentavos) }
        return l.valorCentavos < 0 ? (0, -l.valorCentavos) : (l.valorCentavos, 0)
    }

    /// Para cada devolução (estorno/reembolso), a categoria da compra original, quando dá para achar:
    /// mesma conta, mesmo valor, compra anterior à devolução (até 120 dias).
    static func categoriasDeDevolucao<L: LancamentoAnalisavel>(_ lancamentos: [L], cartoes: Set<String>) -> [String: String] {
        var compras: [Int: [(Date, String, String)]] = [:]
        for l in lancamentos where l.contaParaRelatorios && l.valorCentavos < 0 && l.categoriaChave != "reembolsos" {
            compras[-l.valorCentavos, default: []].append((l.data, l.contaID, l.categoriaChave))
        }
        var saida: [String: String] = [:]
        for l in lancamentos where l.contaParaRelatorios && l.valorCentavos > 0 && l.categoriaChave == "reembolsos" {
            let candidatas = (compras[l.valorCentavos] ?? [])
                .filter { $0.0 <= l.data && Datas.dias(de: $0.0, ate: l.data) <= 120 && ($0.1 == l.contaID || l.contaID.isEmpty) }
                .sorted { $0.0 > $1.0 }
            if let c = candidatas.first { saida[l.externalID] = c.2 }
        }
        return saida
    }

    public static func idsDeCartao(_ contas: [Conta]) -> Set<String> {
        Set(contas.filter { $0.tipo.ehCartao }.map(\.externalID))
    }

    /// `fim` é exclusivo.
    public static func resumo<L: LancamentoAnalisavel>(lancamentos: [L], contas: [Conta], de inicio: Date, ate fim: Date) -> ResumoPeriodo {
        let cartoes = idsDeCartao(contas)
        // A busca da compra original custa uma volta inteira na lista: só quando há devolução no período.
        var origemDaDevolucao: [String: String]?
        var r = ResumoPeriodo(inicio: inicio, fim: fim)
        var despesaPorCat: [String: (Int, Int)] = [:]
        var receitaPorCat: [String: (Int, Int)] = [:]
        for l in lancamentos where l.data >= inicio && l.data < fim && l.contaParaRelatorios {
            let (rec, desp) = fluxo(l, cartao: cartoes.contains(l.contaID))
            if rec == 0 && desp == 0 { continue }
            r.quantidade += 1
            if rec > 0 {
                r.receitasCentavos += rec
                let v = receitaPorCat[l.categoriaChave] ?? (0, 0)
                receitaPorCat[l.categoriaChave] = (v.0 + rec, v.1 + 1)
            } else {
                r.despesasCentavos += desp
                // Devolução abate a categoria da compra original (ou "outros" se não achar).
                var chave = l.categoriaChave
                if desp < 0 {
                    if origemDaDevolucao == nil { origemDaDevolucao = categoriasDeDevolucao(lancamentos, cartoes: cartoes) }
                    chave = origemDaDevolucao?[l.externalID] ?? (l.categoriaChave == "reembolsos" ? "outros" : l.categoriaChave)
                }
                let v = despesaPorCat[chave] ?? (0, 0)
                despesaPorCat[chave] = (v.0 + desp, v.1 + 1)
                r.porDia[Datas.inicioDoDia(l.data), default: 0] += desp
            }
        }
        func ordenar(_ m: [String: (Int, Int)]) -> [GastoCategoria] {
            let positivos = m.filter { $0.value.0 > 0 }
            let total = positivos.values.reduce(0) { $0 + $1.0 }
            return positivos
                .map { GastoCategoria(chave: $0.key, centavos: $0.value.0, quantidade: $0.value.1,
                                      percentual: total > 0 ? Double($0.value.0) / Double(total) : 0) }
                .sorted { $0.centavos > $1.centavos }
        }
        r.porCategoria = ordenar(despesaPorCat)
        r.receitasPorCategoria = ordenar(receitaPorCat)
        return r
    }

    /// No mês corrente, "gasto" é o que já aconteceu até hoje; parcelas pendentes futuras entram só na previsão.
    public static func resumoDoMes<L: LancamentoAnalisavel>(_ mes: Date, lancamentos: [L], contas: [Conta], hoje: Date? = nil) -> ResumoPeriodo {
        let ini = Datas.inicioDoMes(mes)
        var fim = Datas.somar(meses: 1, a: ini)
        let ref = hoje ?? Date()
        if Datas.inicioDoMes(ref) == ini {
            fim = min(fim, Datas.somar(dias: 1, a: Datas.inicioDoDia(ref)))
        }
        return resumo(lancamentos: lancamentos, contas: contas, de: ini, ate: fim)
    }

    /// Série dos últimos `meses` meses, terminando no mês de `ate`.
    public static func serieMensal<L: LancamentoAnalisavel>(lancamentos: [L], contas: [Conta], meses: Int, ate: Date = Date()) -> [PontoMensal] {
        let ultimo = Datas.inicioDoMes(ate)
        return (0..<meses).reversed().map { i in
            let ini = Datas.somar(meses: -i, a: ultimo)
            let r = resumo(lancamentos: lancamentos, contas: contas, de: ini, ate: Datas.somar(meses: 1, a: ini))
            return PontoMensal(mes: ini, receitasCentavos: r.receitasCentavos, despesasCentavos: r.despesasCentavos)
        }
    }

    /// Previsão do gasto total do mês. Usa o histórico: nos últimos 3 meses, que fração do mês já estava gasta
    /// neste mesmo dia? O que falta é a média mensal vezes a fração que costuma faltar. Evita superestimar
    /// quando o aluguel e as contas fixas caem no começo do mês.
    public static func previsaoDoMes<L: LancamentoAnalisavel>(lancamentos: [L], contas: [Conta], hoje: Date = Date()) -> Previsao {
        let ini = Datas.inicioDoMes(hoje)
        let amanha = Datas.somar(dias: 1, a: Datas.inicioDoDia(hoje))
        let ateHoje = resumo(lancamentos: lancamentos, contas: contas, de: ini, ate: amanha).despesasCentavos
        // Compromissos já lançados para o resto do mês (parcelas pendentes, por exemplo).
        let fimMes = Datas.somar(meses: 1, a: ini)
        let futuroConhecido = resumo(lancamentos: lancamentos, contas: contas, de: amanha, ate: fimMes).despesasCentavos
        let cal = Datas.calendario
        let diasNoMes = cal.range(of: .day, in: .month, for: hoje)?.count ?? 30
        let diaAtual = cal.component(.day, from: hoje)
        let restantes = max(0, diasNoMes - diaAtual)

        var totais: [Int] = []
        var fracoes: [Double] = []
        for i in 1...3 {
            let m = Datas.somar(meses: -i, a: ini)
            let mesCheio = resumo(lancamentos: lancamentos, contas: contas, de: m, ate: Datas.somar(meses: 1, a: m)).despesasCentavos
            guard mesCheio > 0 else { continue }
            totais.append(mesCheio)
            let ultimoDia = cal.range(of: .day, in: .month, for: m)?.count ?? 30
            let ate = Datas.somar(dias: min(diaAtual, ultimoDia), a: m)
            let parcial = resumo(lancamentos: lancamentos, contas: contas, de: m, ate: ate).despesasCentavos
            fracoes.append(Double(parcial) / Double(mesCheio))
        }
        let mediaMensal = totais.isEmpty ? 0 : totais.reduce(0, +) / totais.count
        let fracaoJa = fracoes.isEmpty ? 0 : fracoes.reduce(0, +) / Double(fracoes.count)

        var projetado: Int
        if mediaMensal > 0 {
            projetado = ateHoje + Int(Double(mediaMensal) * max(0, 1 - fracaoJa))
        } else {
            // Sem histórico: ritmo do mês atual.
            projetado = diaAtual > 0 ? ateHoje / diaAtual * diasNoMes : ateHoje
        }
        // Nunca abaixo do que já está comprometido.
        projetado = max(projetado, ateHoje + futuroConhecido)
        let porDia = restantes > 0 ? max(0, projetado - ateHoje) / restantes : 0
        return Previsao(gastoAteHojeCentavos: ateHoje, projetadoCentavos: projetado, mediaDiariaCentavos: porDia,
                        diasRestantes: restantes, mediaMensalCentavos: mediaMensal)
    }

    // MARK: Alocação

    public static func alocacao(_ investimentos: [Investimento]) -> [FatiaAlocacao] {
        let ativos = investimentos.filter { $0.ativo && $0.saldoCentavos > 0 }
        let total = ativos.reduce(0) { $0 + $1.saldoCentavos }
        guard total > 0 else { return [] }
        var porClasse: [ClasseAtivo: Int] = [:]
        for i in ativos { porClasse[i.classe, default: 0] += i.saldoCentavos }
        return porClasse
            .map { FatiaAlocacao(classe: $0.key, centavos: $0.value, percentual: Double($0.value) / Double(total)) }
            .sorted { $0.centavos > $1.centavos }
    }

    // MARK: Rendimento

    public static func rendimentoCarteira(_ investimentos: [Investimento]) -> RendimentoCarteira {
        let ativos = investimentos.filter { $0.ativo && $0.saldoCentavos > 0 }
        let saldo = ativos.reduce(0) { $0 + $1.saldoCentavos }
        let comCusto = ativos.filter { ($0.aplicadoCentavos ?? 0) > 0 }
        let aplicado = comCusto.reduce(0) { $0 + ($1.aplicadoCentavos ?? 0) }
        let resultado = comCusto.reduce(0) { $0 + $1.saldoCentavos } - aplicado

        // Rende = saldo − saldo/(1+taxa). Taxas fora do plausível (erro de escala, dado ruim) são ignoradas.
        func estimar(_ taxa: (Investimento) -> Double?, limite: ClosedRange<Double>) -> (centavos: Int, percentual: Double, cobertos: Int)? {
            var rendeu = 0.0, inicio = 0.0, n = 0
            for i in ativos {
                guard let r = taxa(i), limite.contains(r) else { continue }
                let atual = Double(i.saldoCentavos)
                let antes = atual / (1 + r)
                rendeu += atual - antes
                inicio += antes
                n += 1
            }
            guard n > 0, inicio > 0 else { return nil }
            return (Int(rendeu.rounded()), rendeu / inicio, n)
        }
        let mes = estimar({ $0.rentabilidadeMes }, limite: -0.5...1.0)
        let doze = estimar({ $0.rentabilidade12m }, limite: -0.9...5.0)

        return RendimentoCarteira(
            saldoCentavos: saldo, totalInvestimentos: ativos.count,
            aplicadoCentavos: aplicado, resultadoCentavos: resultado,
            resultadoPercentual: aplicado > 0 ? Double(resultado) / Double(aplicado) : nil,
            mesCentavos: mes?.centavos, mesPercentual: mes?.percentual, mesCobertos: mes?.cobertos ?? 0,
            dozeMesesCentavos: doze?.centavos, dozeMesesPercentual: doze?.percentual, dozeMesesCobertos: doze?.cobertos ?? 0)
    }

    // MARK: Orçamento

    public static func orcamento(orcamentos: [Orcamento], resumo: ResumoPeriodo) -> [ItemOrcamento] {
        let gasto = Dictionary(resumo.porCategoria.map { ($0.chave, $0.centavos) }, uniquingKeysWith: +)
        return orcamentos
            .filter { $0.valorCentavos > 0 }
            .map { ItemOrcamento(chave: $0.categoriaChave, limiteCentavos: $0.valorCentavos, gastoCentavos: gasto[$0.categoriaChave] ?? 0) }
            .sorted { $0.percentual > $1.percentual }
    }

    // MARK: Recorrentes (assinaturas, aluguel, salário…)

    /// `meses`: quanto do histórico olhar (a varredura dos fixos usa um ano; o padrão cobre o que o banco local guarda).
    public static func recorrentes<L: LancamentoAnalisavel>(lancamentos: [L], contas: [Conta], hoje: Date = Date(),
                                                            meses: Int = 13) -> [Recorrente] {
        let cartoes = idsDeCartao(contas)
        let desde = Datas.somar(meses: -meses, a: hoje)
        var grupos: [String: [(data: Date, valor: Int, l: L)]] = [:]
        for l in lancamentos where l.data >= desde && l.data <= hoje && l.contaParaRelatorios {
            // Parcelas têm fim; Pix e transferências são para pessoas diferentes a cada vez.
            if (l.totalParcelas ?? 0) > 1 || l.categoria.grupo == .neutro { continue }
            let texto = l.descricaoNormalizada
            if Categorizador.casaPadrao(texto, "pix") || texto.contains("transfer") { continue }
            let (rec, desp) = fluxo(l, cartao: cartoes.contains(l.contaID))
            guard rec > 0 || desp > 0 else { continue }
            let chave = l.chaveDeLoja
            guard !chave.isEmpty else { continue }
            let receita = rec > 0
            grupos["\(receita ? "R" : "D")|\(chave)", default: []].append((data: l.data, valor: receita ? rec : desp, l: l))
        }

        var saida: [Recorrente] = []
        for (chave, pontos) in grupos {
            let p = pontos.sorted { $0.data < $1.data }
            guard p.count >= 3 else { continue }
            let meses = Set(p.map { Datas.inicioDoMes($0.data) })
            guard meses.count >= 3 else { continue }
            // Intervalo mediano entre ocorrências.
            let intervalos = zip(p, p.dropFirst()).map { Datas.dias(de: $0.data, ate: $1.data) }.sorted()
            let mediano = intervalos[intervalos.count / 2]
            guard (24...37).contains(mediano) else { continue }
            let valores = p.map(\.valor).sorted()
            let tipico = valores[valores.count / 2]
            let categoria = p.last!.l.categoriaChave
            let tolerancia = Categorias.contasDeConsumo.contains(categoria) || categoria == "salario" ? 0.6 : 0.3
            let dentro = valores.filter { abs(Double($0 - tipico)) <= Double(tipico) * tolerancia }.count
            guard Double(dentro) / Double(valores.count) >= 0.7 else { continue }
            guard let ultimo = p.last, Datas.dias(de: ultimo.data, ate: hoje) <= 45 else { continue }

            let variacao: Double? = {
                guard p.count >= 2 else { return nil }
                let anterior = p[p.count - 2].valor
                guard anterior > 0 else { return nil }
                return Double(ultimo.valor - anterior) / Double(anterior)
            }()
            let nome = ultimo.l.titulo
            let ocorrencias = p.map {
                OcorrenciaRecorrente(mes: Fixos.chaveMes($0.data), data: $0.data, valorCentavos: $0.valor,
                                     contaID: $0.l.contaID, externalID: $0.l.externalID)
            }
            let dias = p.map { Datas.calendario.component(.day, from: $0.data) }.sorted()
            // Oscilação: o maior desvio entre os valores que ficaram perto do típico (os de fora já são exceção).
            let perto = valores.filter { abs(Double($0 - tipico)) <= Double(tipico) * tolerancia }
            let oscilacao = tipico > 0 ? perto.map { abs(Double($0 - tipico)) / Double(tipico) }.max() ?? 0 : 0
            saida.append(Recorrente(
                id: chave, nome: nome, categoriaChave: categoria, valorCentavos: ultimo.valor,
                ultimaData: ultimo.data, proximaData: Datas.somar(meses: 1, a: ultimo.data),
                ocorrencias: p.count, variacaoUltima: variacao, ehReceita: chave.hasPrefix("R|"),
                contaID: contaPredominante(p.map(\.l.contaID)) ?? ultimo.l.contaID,
                ocorrenciasPorMes: ocorrencias, diaTipico: dias[dias.count / 2], valorTipico: tipico, variacao: oscilacao))
        }
        return saida.sorted { ($0.valorCentavos, $1.id) > ($1.valorCentavos, $0.id) }
    }

    /// A conta que mais aparece; empate fica com a mais recente (a lista vem em ordem de data).
    static func contaPredominante(_ ids: [String]) -> String? {
        guard !ids.isEmpty else { return nil }
        var vezes: [String: Int] = [:]
        var ultimaPosicao: [String: Int] = [:]
        for (i, id) in ids.enumerated() { vezes[id, default: 0] += 1; ultimaPosicao[id] = i }
        return vezes.max { a, b in (a.value, ultimaPosicao[a.key]!) < (b.value, ultimaPosicao[b.key]!) }?.key
    }

    // MARK: Vencimentos

    public static func proximosVencimentos(contas: [Conta], faturas: [Fatura], recorrentes: [Recorrente],
                                           emprestimos: [Emprestimo], hoje: Date = Date(), dias: Int = 14) -> [Vencimento] {
        let inicio = Datas.inicioDoDia(hoje)
        let limite = Datas.somar(dias: dias, a: inicio)
        var lista: [Vencimento] = []
        let contaPorID = Dictionary(contas.map { ($0.externalID, $0) }, uniquingKeysWith: { a, _ in a })

        let limiteDia = Datas.inicioDoDia(limite)
        // Se o banco já informou a fatura do ciclo (paga ou não), não estimamos a partir do saldo.
        var contasComFaturaExata = Set(faturas.filter { Datas.inicioDoDia($0.vencimento) >= inicio }.map(\.contaID))
        for f in faturas where !f.paga && Datas.inicioDoDia(f.vencimento) >= inicio && Datas.inicioDoDia(f.vencimento) <= limiteDia && f.emAberto > 0 {
            let c = contaPorID[f.contaID]
            contasComFaturaExata.insert(f.contaID)
            lista.append(Vencimento(id: "fatura-\(f.externalID)", data: f.vencimento,
                                    titulo: "Fatura \(c?.nomeExibicao ?? "do cartão")",
                                    subtitulo: c?.instituicao ?? "", valorCentavos: f.emAberto, tipo: .fatura, estimado: false))
        }
        for c in contas where c.tipo.ehCartao && !c.arquivada && !contasComFaturaExata.contains(c.externalID) {
            guard let v = c.vencimentoFatura, Datas.inicioDoDia(v) >= inicio, Datas.inicioDoDia(v) <= limiteDia, c.saldoCentavos > 0 else { continue }
            lista.append(Vencimento(id: "cartao-\(c.externalID)", data: v, titulo: "Fatura \(c.nomeExibicao)",
                                    subtitulo: c.instituicao, valorCentavos: c.saldoCentavos, tipo: .fatura, estimado: true))
        }
        for r in recorrentes where !r.ehReceita && Datas.inicioDoDia(r.proximaData) >= inicio && Datas.inicioDoDia(r.proximaData) <= limiteDia {
            lista.append(Vencimento(id: "rec-\(r.id)", data: r.proximaData, titulo: r.nome,
                                    subtitulo: "Recorrente · \(r.categoria.nome)", valorCentavos: r.valorCentavos,
                                    tipo: .recorrente, estimado: true))
        }
        for e in emprestimos {
            guard let v = e.proximoVencimento, Datas.inicioDoDia(v) >= inicio, Datas.inicioDoDia(v) <= limiteDia, let p = e.parcelaCentavos else { continue }
            lista.append(Vencimento(id: "emp-\(e.externalID)", data: v, titulo: e.nome, subtitulo: e.instituicao,
                                    valorCentavos: p, tipo: .emprestimo, estimado: false))
        }
        return lista.sorted { $0.data < $1.data }
    }

    // MARK: Avisos objetivos

    public static func insights<L: LancamentoAnalisavel>(lancamentos: [L], contas: [Conta], investimentos: [Investimento],
                                orcamentos: [Orcamento], recorrentes: [Recorrente], vencimentos: [Vencimento],
                                conexoes: [Conexao], ultimaAtualizacao: Date?,
                                fechamento: FechamentoInvestimentos? = nil, hoje: Date = Date()) -> [Insight] {
        var out: [Insight] = []
        let mes = resumoDoMes(hoje, lancamentos: lancamentos, contas: contas, hoje: hoje)

        // 1. Conexão que precisa de você
        for c in conexoes where c.ativa && !c.demo && c.precisaAtencao {
            out.append(Insight(id: "conexao-\(c.itemID)", severidade: .alerta, icone: "exclamationmark.triangle.fill",
                               titulo: "\(c.nome) precisa de atenção",
                               texto: "A conexão com o banco parou de atualizar. Reconecte no Meu Pluggy para voltar a receber os lançamentos."))
        }
        // 2. Consentimento perto de vencer
        for c in conexoes where c.ativa && !c.demo {
            if let exp = c.consentimentoExpiraEm {
                let d = Datas.dias(de: hoje, ate: exp)
                if d >= 0 && d <= 15 {
                    out.append(Insight(id: "consent-\(c.itemID)", severidade: .atencao, icone: "clock.badge.exclamationmark.fill",
                                       titulo: "Autorização de \(c.nome) vence em \(d) dia\(d == 1 ? "" : "s")",
                                       texto: "O Open Finance pede renovar o consentimento periodicamente. Renove no Meu Pluggy ou no Dashboard da Pluggy e confira se o ID da conexão mudou."))
                }
            }
        }
        // 3. Faturas próximas
        for v in vencimentos where v.tipo == .fatura {
            let d = Datas.dias(de: hoje, ate: v.data)
            if d <= 5 {
                let quando = d <= 0 ? "vence hoje" : (d == 1 ? "vence amanhã" : "vence em \(d) dias")
                out.append(Insight(id: "venc-\(v.id)", severidade: d <= 2 ? .alerta : .atencao, icone: "creditcard.fill",
                                   titulo: "\(v.titulo) \(quando)",
                                   texto: "\(Dinheiro.formatar(v.valorCentavos))\(v.estimado ? " (valor atual da fatura)" : "")."))
            }
        }
        // 4. Orçamentos
        for item in orcamento(orcamentos: orcamentos, resumo: mes) {
            switch item.estado {
            case .estourado:
                out.append(Insight(id: "orc-\(item.chave)", severidade: .alerta, icone: item.info.icone,
                                   titulo: "\(item.info.nome): orçamento estourado",
                                   texto: "Gastou \(Dinheiro.formatar(item.gastoCentavos)) de \(Dinheiro.formatar(item.limiteCentavos)) — \(Dinheiro.formatar(-item.restanteCentavos)) acima."))
            case .atencao:
                out.append(Insight(id: "orc-\(item.chave)", severidade: .atencao, icone: item.info.icone,
                                   titulo: "\(item.info.nome): \(Int(item.percentual * 100))% do orçamento",
                                   texto: "Restam \(Dinheiro.formatar(item.restanteCentavos)) para o resto do mês."))
            case .tranquilo: break
            }
        }
        // 5. Categoria bem acima da média dos 3 meses anteriores
        let ini = Datas.inicioDoMes(hoje)
        var medias: [String: Int] = [:]
        for i in 1...3 {
            let m = Datas.somar(meses: -i, a: ini)
            for g in resumo(lancamentos: lancamentos, contas: contas, de: m, ate: Datas.somar(meses: 1, a: m)).porCategoria {
                medias[g.chave, default: 0] += g.centavos
            }
        }
        let diaAtual = max(1, Datas.calendario.component(.day, from: hoje))
        if diaAtual >= 10 {
            for g in mes.porCategoria.prefix(8) {
                let media = (medias[g.chave] ?? 0) / 3
                // Compara o gasto proporcional ao dia do mês, para não alarmar no dia 3.
                let esperado = Int(Double(media) * Double(diaAtual) / 30.0)
                if media > 0, g.centavos > Int(Double(esperado) * 1.4), g.centavos - esperado > 15_000 {
                    let pct = Int((Double(g.centavos) / Double(max(esperado, 1)) - 1) * 100)
                    out.append(Insight(id: "media-\(g.chave)", severidade: .atencao, icone: g.info.icone,
                                       titulo: "\(g.info.nome) está \(pct)% acima do normal",
                                       texto: "\(Dinheiro.formatar(g.centavos)) até agora; a média dos últimos 3 meses para esta altura do mês é \(Dinheiro.formatar(esperado))."))
                }
            }
        }
        // 6. Reajuste em assinatura
        for r in recorrentes where !r.ehReceita {
            let reajustavel = r.categoria.area == "assinaturas" || Categorias.contasDeConsumo.contains(r.categoriaChave)
            if let v = r.variacaoUltima, v >= 0.08, reajustavel {
                out.append(Insight(id: "reajuste-\(r.id)", severidade: .info, icone: "arrow.up.right.circle.fill",
                                   titulo: "\(r.nome) ficou \(Int((v * 100).rounded()))% mais caro",
                                   texto: "Agora \(Dinheiro.formatar(r.valorCentavos)) por mês."))
            }
        }
        // 7. Dinheiro disponível não cobre o que vence
        let disponivel = contas.filter { !$0.arquivada && !$0.tipo.ehCartao && $0.contaNoPatrimonio }.reduce(0) { $0 + $1.saldoCentavos }
        let aVencer = vencimentos.filter { $0.tipo == .fatura && Datas.dias(de: hoje, ate: $0.data) <= 10 }.reduce(0) { $0 + $1.valorCentavos }
        if aVencer > 0, disponivel < aVencer {
            out.append(Insight(id: "caixa-curto", severidade: .alerta, icone: "exclamationmark.octagon.fill",
                               titulo: "Saldo não cobre as faturas dos próximos dias",
                               texto: "Disponível: \(Dinheiro.formatar(disponivel)). Faturas a vencer: \(Dinheiro.formatar(aVencer))."))
        }
        // 8. Dados desatualizados
        if let u = ultimaAtualizacao, hoje.timeIntervalSince(u) > 36 * 3600, conexoes.contains(where: { !$0.demo }) {
            out.append(Insight(id: "defasado", severidade: .info, icone: "arrow.triangle.2.circlepath",
                               titulo: "Dados dos bancos têm mais de um dia",
                               texto: "A Pluggy atualiza em ciclos, e o intervalo depende do plano dela. Abra o app no Mac para buscar de novo."))
        }
        // 9. Boa notícia: poupou
        if let taxa = mes.taxaDePoupanca, taxa >= 0.2, diaAtual >= 15 {
            out.append(Insight(id: "poupanca", severidade: .positivo, icone: "hand.thumbsup.fill",
                               titulo: "Você está guardando \(Int(taxa * 100))% da renda do mês",
                               texto: "Entrou \(Dinheiro.formatar(mes.receitasCentavos)) e saiu \(Dinheiro.formatar(mes.despesasCentavos))."))
        }
        // 10. Vencimento de investimento
        for i in investimentos where i.ativo {
            if let v = i.vencimento, Datas.inicioDoDia(v) >= Datas.inicioDoDia(hoje) {
                let d = Datas.dias(de: hoje, ate: v)
                if d <= 30 {
                    out.append(Insight(id: "inv-\(i.externalID)", severidade: .info, icone: "calendar.badge.clock",
                                       titulo: "\(i.nome) vence em \(d) dia\(d == 1 ? "" : "s")",
                                       texto: "Saldo de \(Dinheiro.formatar(i.saldoCentavos)). Decida se reaplica ou resgata."))
                }
            }
        }
        // 11. Fechamento dos investimentos, na primeira semana do mês
        if let f = fechamento, diaAtual <= 7, f.taxaMes != nil {
            out.append(Insight(id: "fechamento-\(Fixos.chaveMes(f.mes))", severidade: .info, icone: "chart.line.uptrend.xyaxis",
                               titulo: "Fechamento de \(f.nomeDoMes) dos investimentos", texto: f.frase))
        }
        let ordem: [SeveridadeInsight: Int] = [.alerta: 0, .atencao: 1, .info: 2, .positivo: 3]
        return out.sorted { (ordem[$0.severidade] ?? 9) < (ordem[$1.severidade] ?? 9) }
    }
}

// MARK: - Ritmo do mês

public struct PontoRitmo: Identifiable, Sendable, Equatable {
    public let dia: Int
    /// Gasto acumulado até este dia no mês corrente (nil depois de hoje).
    public let atualCentavos: Int?
    /// Gasto acumulado até este dia no mês anterior.
    public let anteriorCentavos: Int
    public var id: Int { dia }
}

extension Analise {
    /// Compara o gasto acumulado do mês com o do mês anterior, dia a dia.
    public static func ritmoDoMes<L: LancamentoAnalisavel>(lancamentos: [L], contas: [Conta], hoje: Date = Date()) -> [PontoRitmo] {
        let cal = Datas.calendario
        let iniAtual = Datas.inicioDoMes(hoje)
        let iniAnterior = Datas.somar(meses: -1, a: iniAtual)
        let atual = resumo(lancamentos: lancamentos, contas: contas, de: iniAtual, ate: Datas.somar(meses: 1, a: iniAtual))
        let anterior = resumo(lancamentos: lancamentos, contas: contas, de: iniAnterior, ate: iniAtual)
        let diasAtual = cal.range(of: .day, in: .month, for: iniAtual)?.count ?? 30
        let diasAnterior = cal.range(of: .day, in: .month, for: iniAnterior)?.count ?? 30
        let hojeDia = cal.component(.day, from: hoje)
        var acA = 0, acP = 0
        var pontos: [PontoRitmo] = []
        for d in 1...max(diasAtual, diasAnterior) {
            if d <= diasAtual, d <= hojeDia, let data = cal.date(byAdding: .day, value: d - 1, to: iniAtual) {
                acA += atual.porDia[Datas.inicioDoDia(data)] ?? 0
            }
            if d <= diasAnterior, let data = cal.date(byAdding: .day, value: d - 1, to: iniAnterior) {
                acP += anterior.porDia[Datas.inicioDoDia(data)] ?? 0
            }
            pontos.append(PontoRitmo(dia: d, atualCentavos: d <= hojeDia && d <= diasAtual ? acA : nil, anteriorCentavos: acP))
        }
        return pontos
    }
}
