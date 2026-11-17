import Foundation

// MARK: - Áreas

/// O gasto de uma área (ex.: "Carro e transporte") com as categorias que a compõem.
public struct GastoArea: Identifiable, Sendable, Equatable {
    public let chave: String
    public let centavos: Int
    public let quantidade: Int
    public let percentual: Double
    public let categorias: [GastoCategoria]
    public var id: String { chave }
    public var info: AreaCategoria { Categorias.area(chave) }
}

// MARK: - Destaques do mês

public enum TomDestaque: String, Sendable { case neutro, bom, atencao }

/// Uma frase objetiva sobre os gastos do mês: o que se destaca, com o número que prova.
public struct Destaque: Identifiable, Sendable, Equatable {
    public let id: String
    public let tom: TomDestaque
    /// Etiqueta curta ("MAIOR GASTO").
    public let rotulo: String
    /// A frase principal, com o número.
    public let titulo: String
    /// O complemento que explica de onde o número vem.
    public let texto: String
    public let categoriaChave: String?
}

extension Analise {

    /// Junta as categorias por área, da maior para a menor.
    public static func porArea(_ categorias: [GastoCategoria]) -> [GastoArea] {
        let total = categorias.reduce(0) { $0 + $1.centavos }
        var grupos: [String: [GastoCategoria]] = [:]
        for c in categorias { grupos[c.info.area, default: []].append(c) }
        var saida: [GastoArea] = []
        for (chave, lista) in grupos {
            let soma = lista.reduce(0) { $0 + $1.centavos }
            let quantidade = lista.reduce(0) { $0 + $1.quantidade }
            saida.append(GastoArea(chave: chave, centavos: soma, quantidade: quantidade,
                                   percentual: total > 0 ? Double(soma) / Double(total) : 0,
                                   categorias: lista.sorted { $0.centavos > $1.centavos }))
        }
        return saida.sorted { $0.centavos > $1.centavos }
    }

    /// O que chama atenção nos gastos do mês até hoje. Compara sempre com a mesma altura dos meses
    /// anteriores (até o mesmo dia), para o começo do mês não parecer economia.
    public static func destaquesDoMes<L: LancamentoAnalisavel>(lancamentos: [L], contas: [Conta], hoje: Date = Date()) -> [Destaque] {
        let cal = Datas.calendario
        let ini = Datas.inicioDoMes(hoje)
        let amanha = Datas.somar(dias: 1, a: Datas.inicioDoDia(hoje))
        let mes = resumo(lancamentos: lancamentos, contas: contas, de: ini, ate: amanha)
        guard mes.despesasCentavos > 0 else { return [] }
        let dia = cal.component(.day, from: hoje)
        let diasNoMes = cal.range(of: .day, in: .month, for: hoje)?.count ?? 30
        func reais(_ c: Int) -> String { Dinheiro.formatarInteiro(c) }

        // Meses anteriores: o total do mês e quanto já tinha saído até este mesmo dia.
        var parciais: [ResumoPeriodo] = []
        var cheios: [Int] = []
        var parcialDoMesPassado: ResumoPeriodo?
        for i in 1...3 {
            let m = Datas.somar(meses: -i, a: ini)
            let cheio = resumo(lancamentos: lancamentos, contas: contas, de: m, ate: Datas.somar(meses: 1, a: m))
            guard cheio.despesasCentavos > 0 else { continue }
            let ultimoDia = cal.range(of: .day, in: .month, for: m)?.count ?? 30
            let parcial = resumo(lancamentos: lancamentos, contas: contas, de: m, ate: Datas.somar(dias: min(dia, ultimoDia), a: m))
            parciais.append(parcial)
            cheios.append(cheio.despesasCentavos)
            if i == 1 { parcialDoMesPassado = parcial }
        }

        var saida: [Destaque] = []

        // 1. Ritmo: este mês contra o mês passado, até o mesmo dia.
        if let anterior = parcialDoMesPassado, anterior.despesasCentavos > 0 {
            let diferenca = mes.despesasCentavos - anterior.despesasCentavos
            let nome = Datas.nomeDoMes(Datas.somar(meses: -1, a: ini))
            let base = "Até o dia \(dia): \(reais(mes.despesasCentavos)) agora, \(reais(anterior.despesasCentavos)) em \(nome)."
            if abs(diferenca) * 20 < anterior.despesasCentavos {
                saida.append(Destaque(id: "ritmo", tom: .neutro, rotulo: "Ritmo",
                                      titulo: "No mesmo ritmo de \(nome)", texto: base, categoriaChave: nil))
            } else if diferenca > 0 {
                saida.append(Destaque(id: "ritmo", tom: .atencao, rotulo: "Ritmo",
                                      titulo: "\(reais(diferenca)) a mais que em \(nome)", texto: base, categoriaChave: nil))
            } else {
                saida.append(Destaque(id: "ritmo", tom: .bom, rotulo: "Ritmo",
                                      titulo: "\(reais(-diferenca)) a menos que em \(nome)", texto: base, categoriaChave: nil))
            }
        }

        // 2. Quanto ainda cabe por dia para fechar na média.
        let media = cheios.isEmpty ? 0 : cheios.reduce(0, +) / cheios.count
        let diasRestantes = diasNoMes - dia
        if media > 0 {
            let sobra = media - mes.despesasCentavos
            if sobra <= 0 {
                saida.append(Destaque(id: "por-dia", tom: .atencao, rotulo: "Até o fim do mês",
                                      titulo: "Já passou da sua média em \(reais(-sobra))",
                                      texto: "Sua média mensal é \(reais(media)) e faltam \(diasRestantes) dia\(diasRestantes == 1 ? "" : "s").",
                                      categoriaChave: nil))
            } else if diasRestantes > 0 {
                saida.append(Destaque(id: "por-dia", tom: .neutro, rotulo: "Até o fim do mês",
                                      titulo: "Cabem \(reais(sobra / diasRestantes)) por dia",
                                      texto: "Para fechar na sua média de \(reais(media)). Faltam \(diasRestantes) dia\(diasRestantes == 1 ? "" : "s").",
                                      categoriaChave: nil))
            }
        }

        // 3. Onde mais saiu dinheiro no dia a dia (aluguel, condomínio e parcela de empréstimo são sempre os maiores
        //    e não dizem nada de novo).
        let contratos: Set<String> = ["aluguel", "condominio", "emprestimos"]
        if let maior = mes.porCategoria.first(where: { !contratos.contains($0.chave) }) {
            let pct = Int((maior.percentual * 100).rounded())
            saida.append(Destaque(id: "maior-categoria", tom: .neutro, rotulo: "Maior gasto do dia a dia",
                                  titulo: "\(maior.info.nome): \(reais(maior.centavos))",
                                  texto: "\(pct)% do que saiu no mês, em \(maior.quantidade) lançamento\(maior.quantidade == 1 ? "" : "s").",
                                  categoriaChave: maior.chave))
        }

        // 4 e 5. Categorias acima e abaixo do seu normal para esta altura do mês.
        if !parciais.isEmpty {
            var normal: [String: Int] = [:]
            var mesesComGasto: [String: Int] = [:]
            for p in parciais {
                for g in p.porCategoria {
                    normal[g.chave, default: 0] += g.centavos
                    mesesComGasto[g.chave, default: 0] += 1
                }
            }
            // "Normal" só existe para o que se repete: uma viagem de três meses atrás não vira referência.
            let minimo = min(2, parciais.count)
            for (chave, soma) in normal {
                normal[chave] = (mesesComGasto[chave] ?? 0) >= minimo ? soma / parciais.count : 0
            }
            let atual = Dictionary(mes.porCategoria.map { ($0.chave, $0.centavos) }, uniquingKeysWith: +)

            var acima: [(String, Int, Int)] = []
            var abaixo: [(String, Int, Int)] = []
            for chave in Set(normal.keys).union(atual.keys) {
                let agora = atual[chave] ?? 0
                let costuma = normal[chave] ?? 0
                guard costuma > 0 else { continue }
                let diferenca = agora - costuma
                let limite = max(5_000, costuma / 4)
                if diferenca >= limite { acima.append((chave, agora, costuma)) }
                // "Gastou menos" só vale para o que aparece todo mês; compra de vez em quando não é economia.
                if -diferenca >= limite, (mesesComGasto[chave] ?? 0) == parciais.count { abaixo.append((chave, agora, costuma)) }
            }
            for (chave, agora, costuma) in acima.sorted(by: { ($0.1 - $0.2) > ($1.1 - $1.2) }).prefix(2) {
                saida.append(Destaque(id: "acima-\(chave)", tom: .atencao, rotulo: "Acima do normal",
                                      titulo: "\(Categorias.info(chave).nome): \(reais(agora - costuma)) a mais",
                                      texto: "\(reais(agora)) até agora. Nesta altura do mês costuma ser \(reais(costuma)).",
                                      categoriaChave: chave))
            }
            if let (chave, agora, costuma) = abaixo.sorted(by: { ($0.2 - $0.1) > ($1.2 - $1.1) }).first {
                saida.append(Destaque(id: "abaixo-\(chave)", tom: .bom, rotulo: "Abaixo do normal",
                                      titulo: "\(Categorias.info(chave).nome): \(reais(costuma - agora)) a menos",
                                      texto: "\(reais(agora)) até agora. Nesta altura do mês costuma ser \(reais(costuma)).",
                                      categoriaChave: chave))
            }
        }

        // Gastos do mês, um a um (cartão: compra é saída; conta: valor negativo).
        let cartoes = idsDeCartao(contas)
        var gastos: [(l: L, centavos: Int)] = []
        for l in lancamentos where l.data >= ini && l.data < amanha && l.contaParaRelatorios {
            let despesa = fluxo(l, cartao: cartoes.contains(l.contaID)).despesa
            if despesa > 0 { gastos.append((l, despesa)) }
        }

        // 6. O lugar onde você mais voltou.
        var lugares: [String: (vezes: Int, total: Int, nome: String, data: Date)] = [:]
        for g in gastos {
            let chave = g.l.chaveDeLoja
            guard !chave.isEmpty else { continue }
            var v = lugares[chave] ?? (0, 0, g.l.titulo, g.l.data)
            v.vezes += 1
            v.total += g.centavos
            if g.l.data >= v.data { v.nome = g.l.titulo; v.data = g.l.data }
            lugares[chave] = v
        }
        let frequentes = lugares.values.filter { $0.vezes >= 3 }
        if let lugar = frequentes.max(by: { ($0.vezes, $0.total) < ($1.vezes, $1.total) }) {
            saida.append(Destaque(id: "lugar", tom: .neutro, rotulo: "Onde você mais voltou",
                                  titulo: "\(lugar.nome): \(lugar.vezes) vezes, \(reais(lugar.total))",
                                  texto: "Em média \(reais(lugar.total / lugar.vezes)) por vez.",
                                  categoriaChave: nil))
        }

        // 7. Compras pequenas, que somem sem a gente ver.
        let pequenas = gastos.filter { $0.centavos <= 3_000 }
        let somaPequenas = pequenas.reduce(0) { $0 + $1.centavos }
        if pequenas.count >= 5 {
            let pct = Int((Double(somaPequenas) / Double(mes.despesasCentavos) * 100).rounded())
            saida.append(Destaque(id: "pequenas", tom: .neutro, rotulo: "Compras pequenas",
                                  titulo: "\(pequenas.count) compras de até R$ 30 somam \(reais(somaPequenas))",
                                  texto: pct >= 1 ? "\(pct)% do que saiu no mês." : "Menos de 1% do que saiu no mês.",
                                  categoriaChave: nil))
        }

        // 8. A maior compra (fora casa, impostos e parcelas de empréstimo, que são sempre as maiores).
        let avulsos = gastos.filter { !["casa", "financeiro"].contains($0.l.categoria.area) }
        if let maior = avulsos.max(by: { $0.centavos < $1.centavos }), maior.centavos >= 10_000 {
            let d = cal.component(.day, from: maior.l.data)
            saida.append(Destaque(id: "maior-compra", tom: .neutro, rotulo: "Maior compra",
                                  titulo: "\(maior.l.titulo): \(reais(maior.centavos))",
                                  texto: "No dia \(d), em \(maior.l.categoria.nome).",
                                  categoriaChave: maior.l.categoriaChave))
        }

        return saida
    }
}
