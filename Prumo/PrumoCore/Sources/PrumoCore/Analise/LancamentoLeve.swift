import Foundation

/// O que as análises leem de um lançamento. `Lancamento` (o modelo do banco) e `LancamentoLeve` (uma cópia
/// simples) cumprem isto, então toda análise roda com qualquer um dos dois.
public protocol LancamentoAnalisavel {
    var externalID: String { get }
    var contaID: String { get }
    var data: Date { get }
    var descricao: String { get }
    var descricaoOriginal: String? { get }
    var estabelecimento: String? { get }
    var valorCentavos: Int { get }
    var categoriaChave: String { get }
    var interno: Bool { get }
    var ignorado: Bool { get }
    var conciliadoComID: String? { get }
    var parcelaAtual: Int? { get }
    var totalParcelas: Int? { get }
    var criadoEm: Date { get }
    /// Descrição, estabelecimento e descrição original, normalizados (para casar com "como aparece no extrato").
    var textoNormalizado: String { get }
    /// Só a descrição, normalizada.
    var descricaoNormalizada: String { get }
    /// O nome curto do estabelecimento (`Texto.estabelecimento(...).chave`).
    var chaveDeLoja: String { get }
}

extension LancamentoAnalisavel {
    public var textoNormalizado: String {
        Texto.normalizar([descricao, estabelecimento ?? "", descricaoOriginal ?? ""].joined(separator: " "))
    }
    public var descricaoNormalizada: String { Texto.normalizar(descricao) }
    public var chaveDeLoja: String { Categorizador.padraoParaRegra(descricao: descricao, estabelecimento: estabelecimento) }

    /// Entra nas contas de gasto/renda (não é duplicata nem transferência).
    public var contaParaRelatorios: Bool { !interno && !ignorado && conciliadoComID == nil }
    public var categoria: CategoriaInfo { Categorias.info(categoriaChave) }
    public var titulo: String { estabelecimento?.isEmpty == false ? estabelecimento! : Texto.nomeExibicao(descricao) }
    public var valorAbsoluto: Int { abs(valorCentavos) }
}

extension Lancamento: LancamentoAnalisavel {}

/// Cópia simples de um lançamento. Ler uma propriedade do banco (SwiftData) custa caro; as análises leem
/// cada lançamento dezenas de vezes. Copiando uma vez, as contas do painel ficam muitas vezes mais rápidas.
/// Os textos normalizados só são preparados para os últimos meses (onde fixos, recorrentes e destaques olham).
public struct LancamentoLeve: LancamentoAnalisavel, Identifiable, Sendable {
    public let externalID: String
    public let contaID: String
    public let data: Date
    public let descricao: String
    public let descricaoOriginal: String?
    public let estabelecimento: String?
    public let valorCentavos: Int
    public let categoriaChave: String
    public let interno: Bool
    public let ignorado: Bool
    public let conciliadoComID: String?
    public let parcelaAtual: Int?
    public let totalParcelas: Int?
    public let criadoEm: Date
    private let textoPronto: String?
    private let descricaoPronta: String?
    private let lojaPronta: String?

    public var id: String { externalID }

    public init(_ l: Lancamento, prepararTextosDesde corte: Date) {
        externalID = l.externalID
        contaID = l.contaID
        data = l.data
        descricao = l.descricao
        descricaoOriginal = l.descricaoOriginal
        estabelecimento = l.estabelecimento
        valorCentavos = l.valorCentavos
        categoriaChave = l.categoriaChave
        interno = l.interno
        ignorado = l.ignorado
        conciliadoComID = l.conciliadoComID
        parcelaAtual = l.parcelaAtual
        totalParcelas = l.totalParcelas
        criadoEm = l.criadoEm
        if data >= corte {
            textoPronto = Texto.normalizar([descricao, estabelecimento ?? "", descricaoOriginal ?? ""].joined(separator: " "))
            descricaoPronta = Texto.normalizar(descricao)
            lojaPronta = Categorizador.padraoParaRegra(descricao: descricao, estabelecimento: estabelecimento)
        } else {
            textoPronto = nil
            descricaoPronta = nil
            lojaPronta = nil
        }
    }

    public var textoNormalizado: String {
        textoPronto ?? Texto.normalizar([descricao, estabelecimento ?? "", descricaoOriginal ?? ""].joined(separator: " "))
    }
    public var descricaoNormalizada: String { descricaoPronta ?? Texto.normalizar(descricao) }
    public var chaveDeLoja: String { lojaPronta ?? Categorizador.padraoParaRegra(descricao: descricao, estabelecimento: estabelecimento) }

    /// Copia todos de uma vez. Textos preparados para os últimos 13 meses (a varredura dos fixos olha um ano).
    public static func copiar(_ lancamentos: [Lancamento], hoje: Date = Date()) -> [LancamentoLeve] {
        let corte = Datas.somar(meses: -13, a: Datas.inicioDoMes(hoje))
        return lancamentos.map { LancamentoLeve($0, prepararTextosDesde: corte) }
    }
}
