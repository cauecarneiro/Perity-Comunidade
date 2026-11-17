import Foundation
import SwiftData

/// Quando as categorias ficam mais detalhadas, os lançamentos antigos continuam com a categoria ampla
/// ("Transporte"). Isto passa por eles uma vez e troca pela detalhada ("Gasolina", "Uber e táxi").
public enum Recategorizador {
    /// Sobe a cada mudança na lista de categorias; o app guarda a última versão aplicada.
    public static let versao = 3

    /// Para cada categoria detalhada, de quais categorias amplas um lançamento pode ter vindo.
    static let origens: [String: Set<String>] = [
        "aluguel": ["moradia"], "condominio": ["moradia"],
        "luz": ["contas"], "agua_gas": ["contas"], "internet": ["contas"], "celular": ["contas"],
        "delivery": ["restaurantes"], "padaria": ["restaurantes"], "lanches": ["restaurantes"],
        "combustivel": ["transporte"], "estacionamento": ["transporte"], "apps_transporte": ["transporte"],
        "carro": ["transporte", "impostos"],
        "lavagem": ["carro", "transporte", "cuidados"], "carro_taxas": ["carro", "impostos", "transporte"],
        "farmacia": ["saude"], "academia": ["saude"], "plano_saude": ["saude"],
        "lutas": ["academia", "saude", "educacao", "lazer"], "esportes": ["academia", "saude", "lazer"],
        "equipamento_esportivo": ["roupas", "compras", "academia"],
        "streaming": ["assinaturas"], "apps_ia": ["assinaturas"],
        "roupas": ["compras"], "eletronicos": ["compras"],
        "bares": ["lazer"], "jogos": ["lazer"],
        "faculdade": ["educacao"], "cursos": ["educacao"], "livros": ["educacao", "compras"],
        // Mercado Livre e Mercado Pago caíam em "Mercado".
        "compras": ["mercado"],
    ]

    /// Troca a categoria ampla pela detalhada quando o texto do lançamento permite. Nunca mexe no que
    /// você categorizou à mão, nem em regra sua, nem em "interno". Depois, o que ficou em "Outros" e se repete
    /// todo mês com o mesmo valor vira "Outras assinaturas". Devolve quantos mudaram.
    @discardableResult
    public static func refinar(_ ctx: ModelContext) throws -> Int {
        let regras = try ctx.fetch(FetchDescriptor<Regra>())
        let cartoes = Analise.idsDeCartao(try ctx.fetch(FetchDescriptor<Conta>()))
        var mudou = 0
        var semPista: [Lancamento] = []
        for l in try ctx.fetch(FetchDescriptor<Lancamento>()) where !l.categoriaManual && !l.interno {
            let atual = l.categoriaChave
            guard Categorias.info(atual).ehDespesa else { continue }
            let r = Categorizador.categorizar(descricao: l.descricao, estabelecimento: l.estabelecimento,
                                              valorCentavos: l.valorCentavos, ehCartao: cartoes.contains(l.contaID),
                                              regras: regras)
            if r.origem == .padrao, atual == "outros", l.valorCentavos < 0 { semPista.append(l) }
            guard r.origem == .palavraChave, r.chave != atual, Categorias.info(r.chave).ehDespesa else { continue }
            // "Outros" não tinha casado com nada: qualquer palavra nova que case é ganho.
            guard atual == "outros" || origens[r.chave]?.contains(atual) == true else { continue }
            l.categoriaChave = r.chave
            mudou += 1
        }
        mudou += assinaturasPorRecorrencia(semPista)
        if mudou > 0 { try ctx.save() }
        return mudou
    }

    /// Cobrança da mesma loja em 3 meses ou mais, sempre com o mesmo valor (±5%): é assinatura.
    static func assinaturasPorRecorrencia(_ lancamentos: [Lancamento]) -> Int {
        var grupos: [String: [Lancamento]] = [:]
        for l in lancamentos {
            let chave = l.chaveDeLoja
            guard !chave.isEmpty else { continue }
            grupos[chave, default: []].append(l)
        }
        var mudou = 0
        for (_, itens) in grupos {
            let meses = Set(itens.map { Datas.inicioDoMes($0.data) })
            guard meses.count >= 3 else { continue }
            let valores = itens.map(\.valorAbsoluto).sorted()
            let mediana = valores[valores.count / 2]
            guard mediana > 0, valores.allSatisfy({ abs($0 - mediana) * 20 <= mediana }) else { continue }
            for l in itens { l.categoriaChave = "assinaturas"; mudou += 1 }
        }
        return mudou
    }
}
