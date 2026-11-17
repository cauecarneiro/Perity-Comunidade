import Foundation

/// Como um gasto fixo está em um mês.
public struct SituacaoFixo: Identifiable, Sendable, Equatable {
    public let uid: String
    public let nome: String
    public let categoriaChave: String
    public let forma: FormaPagamento
    public let acumula: Bool
    /// Valor de referência do mês: o do extrato quando já apareceu; senão o do mês anterior; senão o combinado.
    public let valorCentavos: Int
    /// Quanto já saiu neste mês segundo o extrato (0 se nada apareceu).
    public let gastoCentavos: Int
    public let pago: Bool
    /// O extrato mostrou o pagamento (ninguém precisou marcar).
    public let detectado: Bool
    /// Marcado ou desmarcado à mão.
    public let manual: Bool
    public let dataPagamento: Date?
    public let parcelaAtual: Int?
    public let totalParcelas: Int?
    public let lancamentoIDs: [String]
    /// De onde saiu neste mês; senão, de onde costuma sair.
    public let contaID: String?
    public let contaNome: String?
    /// Dia do mês em que costuma ser cobrado.
    public let diaTipico: Int?
    /// Quando o dinheiro sai (ou saiu) da conta: no cartão, o vencimento da fatura; nos outros, o dia típico.
    public let previsaoDebito: Date?
    public let origemPrevisao: OrigemPrevisao?
    /// Cobranças dos últimos 12 meses (incluindo este), da mais antiga para a mais nova.
    public let historico: [CobrancaFixo]

    public var id: String { uid }
    public var categoria: CategoriaInfo { Categorias.info(categoriaChave) }
    public var ehCartao: Bool { forma == .cartao }

    /// Quanto ainda falta sair para este item no mês.
    public var faltaCentavos: Int {
        if pago { return 0 }
        return acumula ? max(0, valorCentavos - gastoCentavos) : valorCentavos
    }
}

public enum OrigemPrevisao: String, Sendable {
    /// Vencimento da fatura que contém (ou vai conter) a compra.
    case fatura
    /// Dia em que costuma ser cobrado.
    case diaTipico
}

/// Uma cobrança de um fixo em um mês.
public struct CobrancaFixo: Sendable, Equatable, Identifiable {
    /// "2026-10"
    public let mes: String
    public let data: Date
    public let valorCentavos: Int
    public let contaID: String
    public let externalID: String
    public var id: String { externalID }
}

/// O que a varredura do extrato encontrou: fixos para criar e dados para completar os que já existem.
public struct VarreduraFixos {
    public var novos: [Fixo] = []
    public var enriquecidos: [EnriquecimentoFixo] = []
}

/// Conta e dia típico descobertos para um fixo que estava sem eles.
public struct EnriquecimentoFixo: Sendable, Equatable {
    public let uid: String
    public let contaID: String?
    public let diaTipico: Int?
}

public struct ResumoFixos: Sendable, Equatable {
    public var totalCentavos = 0
    public var pagoCentavos = 0
    public var faltaCentavos = 0
    public var quantidade = 0
    public var pagos = 0
}

/// Um item lido de uma lista colada (uma linha por gasto).
public struct RascunhoFixo: Sendable, Equatable {
    public var nome: String
    public var valorCentavos: Int
    public var forma: FormaPagamento
    public var categoriaChave: String
    public var padrao: String
    public var acumula: Bool
}

public enum Fixos {
    // MARK: Mês

    /// "2026-10"
    public static func chaveMes(_ data: Date) -> String {
        let c = Datas.calendario.dateComponents([.year, .month], from: data)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    // MARK: Casar com o extrato

    /// Alternativas do padrão, já normalizadas. Sem padrão, usa o nome.
    static func alternativas(_ fixo: Fixo) -> [String] {
        let bruto = fixo.padrao.trimmingCharacters(in: .whitespaces).isEmpty ? fixo.nome : fixo.padrao
        return bruto.split(separator: ",").map { Texto.normalizar(String($0)) }.filter { !$0.isEmpty }
    }

    /// Casa a frase inteira ou, se tiver mais de uma palavra, todas as palavras (em qualquer ordem).
    static func casa(_ texto: String, _ alternativas: [String]) -> Bool {
        for alt in alternativas {
            if Categorizador.casaPadrao(texto, alt) { return true }
            let palavras = alt.split(separator: " ").map(String.init).filter { $0.count > 2 }
            if palavras.count > 1, palavras.allSatisfy({ Categorizador.casaPadrao(texto, $0) }) { return true }
        }
        return false
    }

    static func textoDe<L: LancamentoAnalisavel>(_ l: L) -> String { l.textoNormalizado }

    /// Saídas do período que podem ser o pagamento de um fixo.
    private static func saidas<L: LancamentoAnalisavel>(_ lancamentos: [L], de inicio: Date, ate fim: Date) -> [L] {
        lancamentos.filter {
            $0.data >= inicio && $0.data < fim && $0.valorCentavos < 0 && !$0.ignorado && $0.conciliadoComID == nil
        }
    }

    /// Situação de cada fixo no mês. Cada lançamento paga no máximo um fixo de pagamento único
    /// (dois fixos "Vivo" não disputam a mesma cobrança: cada um fica com a de valor mais próximo).
    /// `contas` e `faturas` servem para dizer de onde sai e quando debita; sem elas, esses campos ficam vazios.
    public static func situacao<L: LancamentoAnalisavel>(fixos: [Fixo], marcas: [MarcaFixo], lancamentos: [L], mes: Date,
                                                         contas: [Conta] = [], faturas: [Fatura] = [],
                                                         hoje: Date = Date()) -> [SituacaoFixo] {
        let inicio = Datas.inicioDoMes(mes)
        let fim = Datas.somar(meses: 1, a: inicio)
        let chave = chaveMes(inicio)
        let doMes = saidas(lancamentos, de: inicio, ate: fim).map { (l: $0, texto: textoDe($0)) }
        // Doze meses para trás, do mais recente para o mais antigo: histórico e referência de valor.
        let inicioHistorico = Datas.somar(meses: -11, a: inicio)
        let anteriores = saidas(lancamentos, de: inicioHistorico, ate: inicio)
            .sorted { $0.data > $1.data }
            .map { (l: $0, texto: textoDe($0)) }
        let referenciaDesde = Datas.somar(meses: -3, a: inicio)
        let marcaPorFixo = Dictionary(marcas.filter { $0.mes == chave }.map { ($0.fixoUID, $0) },
                                      uniquingKeysWith: { a, b in a.marcadoEm >= b.marcadoEm ? a : b })
        let contaPorID = Dictionary(contas.map { ($0.externalID, $0) }, uniquingKeysWith: { a, _ in a })
        let cartoes = Analise.idsDeCartao(contas)
        let unicoCartao = contas.filter { $0.tipo.ehCartao && !$0.arquivada }.count == 1 ? contas.first { $0.tipo.ehCartao && !$0.arquivada } : nil

        var usados = Set<String>()
        var usadosNoPassado = Set<String>()
        var saida: [SituacaoFixo] = []
        let ordenados = fixos.filter(\.ativo).sorted { ($0.ordem, $0.criadoEm) < ($1.ordem, $1.criadoEm) }

        for fixo in ordenados {
            let alts = alternativas(fixo)
            let marca = marcaPorFixo[fixo.uid]
            var gasto = 0
            var detectado = false
            var data: Date?
            var parcela: (Int, Int)?
            var ids: [String] = []
            var referencia = fixo.valorCentavos
            var historico: [CobrancaFixo] = []
            var contaDoMes: String?

            if fixo.acumula {
                // Soma tudo que casa com o padrão; sem padrão próprio, soma a categoria.
                let usaCategoria = fixo.padrao.trimmingCharacters(in: .whitespaces).isEmpty
                func pertence(_ par: (l: L, texto: String)) -> Bool {
                    usaCategoria ? (par.l.categoriaChave == fixo.categoriaChave && !par.l.interno) : casa(par.texto, alts)
                }
                let itens = doMes.filter(pertence)
                gasto = itens.reduce(0) { $0 + $1.l.valorAbsoluto }
                ids = itens.map(\.l.externalID)
                data = itens.map(\.l.data).max()
                contaDoMes = Analise.contaPredominante(itens.sorted { $0.l.data < $1.l.data }.map(\.l.contaID))
                historico = (anteriores.filter(pertence) + itens).map(cobranca).sorted { $0.data < $1.data }
            } else {
                let candidatos = doMes.filter { !usados.contains($0.l.externalID) && casa($0.texto, alts) }
                // Referência: o último valor real em meses anteriores. Se a mesma loja cobra coisas diferentes
                // (Apple: R$ 8, R$ 19,90, R$ 25), fica com a mais recente perto do combinado (até 50% de diferença).
                let passados = anteriores.filter { $0.l.data >= referenciaDesde && casa($0.texto, alts) }
                let combinado = fixo.valorCentavos
                let perto = passados.first { combinado > 0 && abs($0.l.valorAbsoluto - combinado) * 2 <= combinado }
                if let ultimo = perto ?? passados.first { referencia = ultimo.l.valorAbsoluto }
                if let escolhido = candidatos.min(by: { abs($0.l.valorAbsoluto - referencia) < abs($1.l.valorAbsoluto - referencia) }) {
                    usados.insert(escolhido.l.externalID)
                    detectado = true
                    gasto = escolhido.l.valorAbsoluto
                    referencia = gasto
                    data = escolhido.l.data
                    ids = [escolhido.l.externalID]
                    contaDoMes = escolhido.l.contaID
                    if let p = escolhido.l.parcelaAtual, let t = escolhido.l.totalParcelas, t > 1 { parcela = (p, t) }
                }
                // Histórico: uma cobrança por mês, a de valor mais próximo da referência; cada lançamento serve a um fixo só.
                var porMes: [String: (l: L, texto: String)] = [:]
                for par in anteriores where !usadosNoPassado.contains(par.l.externalID) && casa(par.texto, alts) {
                    let m = chaveMes(par.l.data)
                    if let atual = porMes[m], abs(atual.l.valorAbsoluto - referencia) <= abs(par.l.valorAbsoluto - referencia) { continue }
                    porMes[m] = par
                }
                for par in porMes.values { usadosNoPassado.insert(par.l.externalID) }
                historico = porMes.values.map(cobranca).sorted { $0.data < $1.data }
                if detectado, let escolhido = candidatos.first(where: { $0.l.externalID == ids[0] }) { historico.append(cobranca(escolhido)) }
            }

            let pago = marca?.pago ?? detectado
            // Soma do mês: fechado (marcado como pago) vale o que saiu de verdade; aberto vale o combinado, ou mais se já passou.
            let valorSoma = pago ? (gasto > 0 ? gasto : fixo.valorCentavos) : max(fixo.valorCentavos, gasto)

            let contaID = contaDoMes ?? fixo.contaID ?? Analise.contaPredominante(historico.map(\.contaID))
            let diaTipico = fixo.diaTipico ?? (fixo.acumula ? nil : diaMediano(historico.map(\.data)))
            let ehCartao = fixo.forma == .cartao || (contaID.map { cartoes.contains($0) } ?? false)
            let conta = contaID.flatMap { contaPorID[$0] } ?? (ehCartao ? unicoCartao : nil)
            let previsao = previsaoDeDebito(cartao: ehCartao, conta: conta, faturas: faturas, pago: pago,
                                            dataPagamento: data, diaTipico: diaTipico, mes: inicio, hoje: hoje)

            saida.append(SituacaoFixo(
                uid: fixo.uid, nome: fixo.nome, categoriaChave: fixo.categoriaChave, forma: fixo.forma, acumula: fixo.acumula,
                valorCentavos: fixo.acumula ? valorSoma : referencia,
                gastoCentavos: gasto, pago: pago, detectado: detectado, manual: marca != nil,
                dataPagamento: data, parcelaAtual: parcela?.0, totalParcelas: parcela?.1, lancamentoIDs: ids,
                contaID: contaID, contaNome: contaID.flatMap { contaPorID[$0]?.nomeExibicao },
                diaTipico: diaTipico, previsaoDebito: previsao?.data, origemPrevisao: previsao?.origem,
                historico: historico))
        }
        return saida
    }

    private static func cobranca<L: LancamentoAnalisavel>(_ par: (l: L, texto: String)) -> CobrancaFixo {
        CobrancaFixo(mes: chaveMes(par.l.data), data: par.l.data, valorCentavos: par.l.valorAbsoluto,
                     contaID: par.l.contaID, externalID: par.l.externalID)
    }

    static func diaMediano(_ datas: [Date]) -> Int? {
        guard !datas.isEmpty else { return nil }
        let dias = datas.map { Datas.calendario.component(.day, from: $0) }.sorted()
        return dias[dias.count / 2]
    }

    /// Cartão: já cobrado → vencimento da fatura que contém a compra; ainda não → a compra é esperada no dia típico
    /// e entra na fatura correspondente. Débito, Pix e boleto: o dia típico neste mês, ou no próximo se já passou sem pagar.
    private static func previsaoDeDebito(cartao: Bool, conta: Conta?, faturas: [Fatura], pago: Bool, dataPagamento: Date?,
                                         diaTipico: Int?, mes inicio: Date, hoje: Date) -> (data: Date, origem: OrigemPrevisao)? {
        if cartao {
            guard let conta else { return nil }
            if let compra = dataPagamento {
                return Faturas.dataDeDebito(compra: compra, conta: conta, faturas: faturas).map { ($0, .fatura) }
            }
            if pago { return nil }
            if let dia = diaTipico {
                return Faturas.dataDeDebito(compra: Faturas.data(dia: dia, noMesDe: inicio), conta: conta, faturas: faturas).map { ($0, .fatura) }
            }
            if let v = conta.vencimentoFatura, Datas.inicioDoDia(v) >= Datas.inicioDoDia(hoje) { return (v, .fatura) }
            return nil
        }
        guard !pago, let dia = diaTipico else { return nil }
        var data = Faturas.data(dia: dia, noMesDe: inicio)
        let mesAtual = Datas.inicioDoMes(hoje) == inicio
        if mesAtual && Datas.inicioDoDia(data) < Datas.inicioDoDia(hoje) {
            data = Faturas.data(dia: dia, noMesDe: Datas.somar(meses: 1, a: inicio))
        }
        return (data, .diaTipico)
    }

    public static func resumo(_ itens: [SituacaoFixo]) -> ResumoFixos {
        var r = ResumoFixos()
        for s in itens {
            r.quantidade += 1
            r.totalCentavos += s.valorCentavos
            r.faltaCentavos += s.faltaCentavos
            if s.pago { r.pagos += 1 }
        }
        r.pagoCentavos = max(0, r.totalCentavos - r.faltaCentavos)
        return r
    }

    // MARK: Sugestões

    /// Gastos que se repetem todo mês e ainda não estão na lista de fixos.
    public static func sugestoes(recorrentes: [Recorrente], fixos: [Fixo]) -> [Recorrente] {
        let ativos = fixos.filter(\.ativo)
        return recorrentes.filter { rec in
            guard !rec.ehReceita else { return false }
            let texto = Texto.normalizar(rec.nome + " " + rec.id.replacingOccurrences(of: "D|", with: ""))
            return !ativos.contains { fixo in
                if fixo.acumula && fixo.padrao.trimmingCharacters(in: .whitespaces).isEmpty {
                    return fixo.categoriaChave == rec.categoriaChave
                }
                return casa(texto, alternativas(fixo))
            }
        }
    }

    /// Cria um fixo a partir de um gasto recorrente detectado.
    public static func novo(de rec: Recorrente, ehCartao: Bool, automatico: Bool = false) -> Fixo {
        let padrao = rec.id.hasPrefix("D|") ? String(rec.id.dropFirst(2)) : Texto.normalizar(rec.nome)
        let forma: FormaPagamento = ehCartao ? .cartao : (formaPeloTexto(rec.nome) ?? .debito)
        return Fixo(nome: Texto.nomeExibicao(rec.nome), valorCentavos: rec.valorTipico, forma: forma,
                    categoriaChave: rec.categoriaChave, padrao: padrao, contaID: rec.contaID,
                    diaTipico: rec.diaTipico, automatico: automatico)
    }

    private static func formaPeloTexto(_ texto: String) -> FormaPagamento? {
        let t = Texto.normalizar(texto)
        if t.contains("boleto") { return .boleto }
        if Categorizador.casaPadrao(t, "pix") { return .pix }
        if t.contains("debito") { return .debito }
        return nil
    }

    // MARK: Varredura

    /// Categorias que são conta fixa por natureza: entram mesmo quando o valor oscila (luz, plano, faculdade…).
    static let categoriasSempreFixas: Set<String> = Categorias.contasDeConsumo.union([
        "aluguel", "condominio", "plano_saude", "academia", "lutas", "esportes", "faculdade", "cursos", "educacao",
        "seguros", "emprestimos", "streaming", "apps_ia", "assinaturas",
    ])

    /// Olha o que se repete no extrato e devolve o que virar fixo sozinho, mais conta e dia típico para os fixos
    /// que ainda não têm. Critério para criar: ≥3 meses distintos nos últimos 5, com valor estável (oscila até 25%)
    /// ou categoria que é conta fixa por natureza. Nada que case com um fixo já existente, ativo ou desativado.
    public static func varrer<L: LancamentoAnalisavel>(recorrentes: [Recorrente], fixos: [Fixo], contas: [Conta],
                                                       lancamentos: [L], hoje: Date = Date()) -> VarreduraFixos {
        var saida = VarreduraFixos()
        let cartoes = Analise.idsDeCartao(contas)
        let inicioJanela = Datas.somar(meses: -4, a: Datas.inicioDoMes(hoje))

        for rec in recorrentes where !rec.ehReceita && rec.categoria.grupo != .neutro {
            let mesesRecentes = Set(rec.ocorrenciasPorMes.filter { $0.data >= inicioJanela }.map(\.mes))
            guard mesesRecentes.count >= 3 else { continue }
            let estavel = rec.variacao <= 0.25
            guard estavel || categoriasSempreFixas.contains(rec.categoriaChave) || rec.categoria.area == "assinaturas" else { continue }
            guard !jaCoberto(rec, por: fixos) else { continue }
            saida.novos.append(novo(de: rec, ehCartao: cartoes.contains(rec.contaID), automatico: true))
        }

        let desde = Datas.somar(meses: -13, a: Datas.inicioDoMes(hoje))
        let passado = saidas(lancamentos, de: desde, ate: hoje).map { (l: $0, texto: textoDe($0)) }
        for fixo in fixos where fixo.ativo && (fixo.contaID == nil || (fixo.diaTipico == nil && !fixo.acumula)) {
            let alts = alternativas(fixo)
            let usaCategoria = fixo.acumula && fixo.padrao.trimmingCharacters(in: .whitespaces).isEmpty
            let casados = passado.filter { usaCategoria ? ($0.l.categoriaChave == fixo.categoriaChave && !$0.l.interno) : casa($0.texto, alts) }
                .sorted { $0.l.data < $1.l.data }
            guard casados.count >= 2 else { continue }
            let contaID = fixo.contaID == nil ? Analise.contaPredominante(casados.map(\.l.contaID)) : nil
            let dia = (fixo.diaTipico == nil && !fixo.acumula) ? diaMediano(casados.map(\.l.data)) : nil
            if contaID != nil || dia != nil {
                saida.enriquecidos.append(EnriquecimentoFixo(uid: fixo.uid, contaID: contaID, diaTipico: dia))
            }
        }
        return saida
    }

    /// Um recorrente já tem fixo quando casa com o padrão de algum (ativo ou não) ou é a categoria de um que soma.
    private static func jaCoberto(_ rec: Recorrente, por fixos: [Fixo]) -> Bool {
        let chave = rec.id.hasPrefix("D|") ? String(rec.id.dropFirst(2)) : Texto.normalizar(rec.nome)
        let texto = Texto.normalizar(rec.nome + " " + chave)
        return fixos.contains { fixo in
            if fixo.acumula && fixo.padrao.trimmingCharacters(in: .whitespaces).isEmpty {
                return fixo.categoriaChave == rec.categoriaChave
            }
            if Texto.normalizar(fixo.padrao) == chave { return true }
            return casa(texto, alternativas(fixo))
        }
    }

    // MARK: Lista colada

    /// Como as pessoas escrevem a categoria numa lista. O que não estiver aqui é procurado pelo nome da categoria.
    private static let apelidosDeCategoria: [String: String] = [
        "casa": "moradia", "neutro": "outros", "assinatura": "assinaturas", "seguro": "seguros",
        "gasolina": "combustivel", "combustivel": "combustivel", "uber": "apps_transporte", "taxi": "apps_transporte",
        "energia": "luz", "agua": "agua_gas", "gas": "agua_gas", "telefone": "celular", "internet": "internet",
        "ia": "apps_ia", "apps": "apps_ia", "app": "apps_ia", "esporte": "esportes", "esportes": "esportes",
        "academia": "academia", "luta": "lutas", "lutas": "lutas", "jiu jitsu": "lutas", "faculdade": "faculdade",
        "curso": "cursos", "livro": "livros", "lanche": "lanches", "lavagem": "lavagem", "ipva": "carro_taxas",
        "jogo": "jogos", "games": "jogos",
        "plano": "plano_saude", "restaurante": "restaurantes", "cafe": "padaria", "padaria": "padaria",
        "bar": "bares", "roupa": "roupas", "roupas": "roupas", "eletronico": "eletronicos", "compra": "compras",
        "imposto": "impostos", "tarifa": "tarifas", "emprestimo": "emprestimos", "pet": "pets",
        "presente": "presentes", "transporte": "transporte", "saude": "saude", "lazer": "lazer",
    ]

    private static func forma(_ texto: String) -> FormaPagamento? {
        let t = Texto.normalizar(texto)
        if t.contains("cartao") || t.contains("credito") { return .cartao }
        if t.contains("boleto") { return .boleto }
        if t == "pix" { return .pix }
        if t.contains("debito") { return .debito }
        return nil
    }

    private static func categoria(_ texto: String) -> String? {
        let t = Texto.normalizar(texto)
        if let c = apelidosDeCategoria[t] { return c }
        return Categorias.todas.first { Texto.normalizar($0.nome) == t || $0.chave == t }?.chave
    }

    /// Lê uma lista colada, uma linha por gasto, com os campos separados por ";" ou tabulação, em qualquer ordem:
    /// `Academia; 299,00; cartão; saúde` · `Mercado; 1.800,00; cartão; mercado; soma` · `Claude; 500; cartão; extrato=claude, anthropic`
    public static func ler(_ texto: String) -> [RascunhoFixo] {
        var saida: [RascunhoFixo] = []
        for linha in texto.components(separatedBy: .newlines) {
            let campos = linha.components(separatedBy: CharacterSet(charactersIn: ";\t"))
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard campos.count >= 2 else { continue }
            var nome: String?
            var valor: Int?
            var formaLida: FormaPagamento?
            var cat: String?
            var padrao = ""
            var acumula = false
            for campo in campos {
                let n = Texto.normalizar(campo)
                if n.hasPrefix("extrato") {
                    let partes = campo.split(separator: "=", maxSplits: 1)
                    if partes.count == 2 { padrao = partes[1].trimmingCharacters(in: .whitespaces) }
                } else if n == "soma" || n == "varios" {
                    acumula = true
                } else if valor == nil, campo.contains(where: \.isNumber),
                          !campo.contains(where: { $0.isLetter && !"rR$".contains($0) }), let v = Dinheiro.ler(campo) {
                    valor = abs(v)
                } else if nome == nil {
                    nome = campo
                } else if formaLida == nil, let f = forma(campo) {
                    formaLida = f
                } else if cat == nil, let c = categoria(campo) {
                    cat = c
                }
            }
            guard let nome, let valor, valor > 0 else { continue }
            saida.append(RascunhoFixo(nome: nome, valorCentavos: valor, forma: formaLida ?? .outro,
                                      categoriaChave: cat ?? "outros", padrao: padrao, acumula: acumula))
        }
        return saida
    }
}
