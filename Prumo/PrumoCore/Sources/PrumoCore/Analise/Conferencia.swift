import Foundation

/// Uma loja (chave de estabelecimento) e onde os gastos dela caíram, para conferir a categorização.
public struct LojaConferida: Identifiable, Sendable, Equatable {
    public let chave: String
    public let nome: String
    /// A categoria mais comum entre os lançamentos dessa loja.
    public let categoriaChave: String
    public let vezes: Int
    public let totalCentavos: Int
    /// 0 a 100. 100 = regra sua; baixo = o app chutou ("Outros" ou palavra fraca).
    public let confianca: Int
    public let externalIDs: [String]

    public var id: String { chave }
    public var categoria: CategoriaInfo { Categorias.info(categoriaChave) }
}

extension Analise {
    /// Agrupa os gastos dos últimos meses por loja, com a categoria atual e quanto dá para confiar nela.
    /// Ordem: o que está em "Outros" primeiro, depois a menor confiança, depois o maior total.
    ///
    /// Confiança: regra sua = 100; categoria igual à que o dicionário dá hoje = a confiança do dicionário;
    /// categoria diferente da que o dicionário dá (veio do banco ou da sua mão) = 60, porque o analisável leve
    /// não carrega a categoria do banco nem a marca de "manual".
    public static func conferenciaCategorias<L: LancamentoAnalisavel>(lancamentos: [L], contas: [Conta], regras: [Regra] = [],
                                                                     hoje: Date = Date(), meses: Int = 12) -> [LojaConferida] {
        let cartoes = idsDeCartao(contas)
        let desde = Datas.somar(meses: -meses, a: Datas.inicioDoMes(hoje))
        var grupos: [String: [L]] = [:]
        for l in lancamentos where l.data >= desde && l.data <= hoje && l.contaParaRelatorios {
            guard fluxo(l, cartao: cartoes.contains(l.contaID)).despesa > 0 else { continue }
            let chave = l.chaveDeLoja
            guard !chave.isEmpty else { continue }
            grupos[chave, default: []].append(l)
        }

        var saida: [LojaConferida] = []
        for (chave, itens) in grupos {
            var porCategoria: [String: Int] = [:]
            for l in itens { porCategoria[l.categoriaChave, default: 0] += 1 }
            let categoria = porCategoria.max { ($0.value, $0.key) < ($1.value, $1.key) }!.key
            let ultimo = itens.max { $0.data < $1.data }!
            let r = Categorizador.categorizar(descricao: ultimo.descricao, estabelecimento: ultimo.estabelecimento,
                                              valorCentavos: ultimo.valorCentavos, ehCartao: cartoes.contains(ultimo.contaID),
                                              regras: regras)
            let confianca: Int
            if r.origem == .regraDoUsuario { confianca = 100 }
            else if r.chave == categoria { confianca = r.confianca }
            else { confianca = 60 }
            saida.append(LojaConferida(
                chave: chave, nome: ultimo.titulo, categoriaChave: categoria, vezes: itens.count,
                totalCentavos: itens.reduce(0) { $0 + $1.valorAbsoluto }, confianca: confianca,
                externalIDs: itens.sorted { $0.data > $1.data }.map(\.externalID)))
        }
        return saida.sorted {
            let a = ($0.categoriaChave == "outros" ? 0 : 1, $0.confianca, -$0.totalCentavos, $0.chave)
            let b = ($1.categoriaChave == "outros" ? 0 : 1, $1.confianca, -$1.totalCentavos, $1.chave)
            return a < b
        }
    }
}
