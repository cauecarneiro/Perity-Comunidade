import Foundation
import SwiftData

/// Casa lançamentos que chegam na hora (Apple Pay / digitados) com os que o banco confirma depois,
/// para o mesmo gasto não aparecer duas vezes. Também reconhece o que é "interno": pagamento de
/// fatura e transferência entre contas suas.
public enum Conciliador {

    /// Quantos dias depois do toque no Apple Pay o banco ainda pode lançar. O banco nunca lança *antes*
    /// do toque, a não ser por 1 dia de fuso/virada.
    public static let diasDepois = 5
    public static let diasAntes = 1

    private static func palavras(_ l: Lancamento) -> Set<String> {
        Set(Texto.normalizar(l.descricao + " " + (l.estabelecimento ?? ""))
            .components(separatedBy: " ")
            .filter { $0.count > 2 && !Categorizador.palavrasGenericas.contains($0) })
    }

    @discardableResult
    public static func conciliar(_ contexto: ModelContext) throws -> Int {
        let carteira = OrigemLancamento.carteira.rawValue
        let manual = OrigemLancamento.manual.rawValue
        let provisorios = try contexto.fetch(FetchDescriptor<Lancamento>(
            predicate: #Predicate { $0.conciliadoComID == nil && !$0.ignorado && ($0.origemRaw == carteira || $0.origemRaw == manual) },
            sortBy: [SortDescriptor(\.data)]
        ))
        guard let maisAntigo = provisorios.map(\.data).min() else { return 0 }

        let banco = OrigemLancamento.openFinance.rawValue
        let importado = OrigemLancamento.importado.rawValue
        let limite = Datas.somar(dias: -diasAntes - 1, a: maisAntigo)
        let oficiais = try contexto.fetch(FetchDescriptor<Lancamento>(
            predicate: #Predicate { ($0.origemRaw == banco || $0.origemRaw == importado) && $0.data >= limite && !$0.interno && !$0.ignorado }
        ))
        // Lançamentos oficiais que já foram "tomados" por outro provisório.
        let todosConciliados = try contexto.fetch(FetchDescriptor<Lancamento>(
            predicate: #Predicate { $0.conciliadoComID != nil }
        ))
        var usados = Set(todosConciliados.compactMap(\.conciliadoComID))

        var total = 0
        for p in provisorios {
            if p.origem == .manual && p.contaID.isEmpty { continue }   // dinheiro vivo não tem par no banco
            let tokensP = palavras(p)
            let candidatos = oficiais.filter { o in
                guard !usados.contains(o.externalID) else { return false }
                guard p.contaID.isEmpty || p.contaID == o.contaID else { return false }
                let dias = Datas.dias(de: p.data, ate: o.data)
                guard dias >= -diasAntes && dias <= diasDepois else { return false }
                // Mesmo valor, ou uma parcela de uma compra parcelada (10x R$ 100 para um toque de R$ 1.000).
                let mesmoValor = o.valorCentavos == p.valorCentavos
                var parcela = false
                if let n = o.totalParcelas, n > 1 {
                    let tolerancia = max(100, abs(p.valorCentavos) / 100)
                    parcela = abs(o.valorCentavos * n - p.valorCentavos) <= tolerancia
                }
                guard mesmoValor || parcela else { return false }
                // Sem conta definida, o texto precisa ter algo em comum; senão qualquer R$ 50 casaria com qualquer R$ 50.
                if p.contaID.isEmpty, !tokensP.isEmpty, tokensP.intersection(palavras(o)).isEmpty { return false }
                return true
            }
            guard !candidatos.isEmpty else { continue }
            let escolhido = melhor(candidatos, para: p, tokens: tokensP)
            p.conciliadoComID = escolhido.externalID
            p.atualizadoEm = Date()
            // O que você já tinha acertado no provisório passa para o oficial.
            if p.categoriaManual && !escolhido.categoriaManual {
                escolhido.categoriaChave = p.categoriaChave
                escolhido.categoriaManual = true
            }
            if let n = p.notas, escolhido.notas == nil { escolhido.notas = n }
            usados.insert(escolhido.externalID)
            total += 1
        }
        if total > 0 { try contexto.save() }
        return total
    }

    private static func melhor(_ candidatos: [Lancamento], para p: Lancamento, tokens: Set<String>) -> Lancamento {
        func pontos(_ o: Lancamento) -> Int {
            let comuns = tokens.intersection(palavras(o)).count
            let proximidade = max(0, diasDepois - abs(Datas.dias(de: p.data, ate: o.data)))
            return comuns * 10 + proximidade
        }
        return candidatos.max { pontos($0) < pontos($1) } ?? candidatos[0]
    }

    // MARK: Pagamento de fatura (par: débito na conta + "pagamento recebido" no cartão)

    /// Marca como interno o débito na conta que paga uma fatura de cartão que o app acompanha.
    /// Só pareia quando o cartão está no app; sem ele, o dinheiro realmente saiu e conta como gasto.
    @discardableResult
    public static func parearFaturas(_ contexto: ModelContext) throws -> Int {
        let contas = try contexto.fetch(FetchDescriptor<Conta>())
        let cartoes = Set(contas.filter { $0.tipo.ehCartao }.map(\.externalID))
        guard !cartoes.isEmpty else { return 0 }
        let todos = try contexto.fetch(FetchDescriptor<Lancamento>())
        let pagamentos = todos.filter { cartoes.contains($0.contaID) && $0.valorCentavos > 0 && $0.interno && $0.conciliadoComID == nil }
            .sorted { $0.data < $1.data }
        var debitos = todos.filter {
            !cartoes.contains($0.contaID) && $0.valorCentavos < 0 && !$0.interno && !$0.internoManual && !$0.ignorado
                && $0.conciliadoComID == nil && ($0.origem == .openFinance || $0.origem == .importado)
        }
        var total = 0
        for pag in pagamentos {
            guard let i = debitos.firstIndex(where: {
                $0.valorCentavos == -pag.valorCentavos && abs(Datas.dias(de: pag.data, ate: $0.data)) <= 3
            }) else { continue }
            let d = debitos.remove(at: i)
            d.interno = true
            if !d.categoriaManual { d.categoriaChave = "fatura" }
            total += 1
        }
        if total > 0 { try contexto.save() }
        return total
    }

    // MARK: Transferência entre contas próprias (par: saída numa conta, entrada na outra)

    @discardableResult
    public static func parearTransferenciasProprias(_ contexto: ModelContext) throws -> Int {
        let contas = try contexto.fetch(FetchDescriptor<Conta>())
        let cartoes = Set(contas.filter { $0.tipo.ehCartao }.map(\.externalID))
        let marcas = ["pix", "ted", "doc", "transf"]
        let todos = try contexto.fetch(FetchDescriptor<Lancamento>())
        let candidatos = todos.filter { l in
            guard !cartoes.contains(l.contaID), !l.contaID.isEmpty, !l.interno, !l.internoManual, !l.ignorado,
                  l.conciliadoComID == nil, l.origem == .openFinance || l.origem == .importado else { return false }
            let t = Texto.normalizar(l.descricao)
            return marcas.contains { Categorizador.casaPadrao(t, $0) || t.contains("transf") }
        }
        var saidas = candidatos.filter { $0.valorCentavos < 0 }.sorted { $0.data < $1.data }
        let entradas = candidatos.filter { $0.valorCentavos > 0 }.sorted { $0.data < $1.data }
        var total = 0
        for e in entradas {
            guard let i = saidas.firstIndex(where: {
                $0.valorCentavos == -e.valorCentavos && $0.contaID != e.contaID && abs(Datas.dias(de: $0.data, ate: e.data)) <= 2
            }) else { continue }
            let s = saidas.remove(at: i)
            for l in [s, e] {
                l.interno = true
                if !l.categoriaManual { l.categoriaChave = "transferencia" }
            }
            total += 1
        }
        if total > 0 { try contexto.save() }
        return total
    }
}

/// Remove duplicatas criadas quando dois aparelhos escrevem a mesma coisa antes do iCloud sincronizar.
public enum Higiene {

    @discardableResult
    public static func deduplicar(_ contexto: ModelContext) throws -> Int {
        var removidos = 0

        func limpar<T: PersistentModel>(_ tipo: T.Type, chave: (T) -> String, preferir: (T, T) -> Bool) throws {
            let todos = try contexto.fetch(FetchDescriptor<T>())
            var grupos: [String: [T]] = [:]
            for item in todos {
                let k = chave(item)
                if k.isEmpty { continue }
                grupos[k, default: []].append(item)
            }
            for (_, grupo) in grupos where grupo.count > 1 {
                let ordenado = grupo.sorted { preferir($0, $1) }
                for extra in ordenado.dropFirst() {
                    contexto.delete(extra)
                    removidos += 1
                }
            }
        }

        try limpar(Lancamento.self, chave: { "\($0.contaID)|\($0.externalID)" }) { a, b in
            // Prefere o que você editou, depois o mais antigo.
            let ea = a.categoriaManual || a.internoManual || a.notas != nil || a.ignorado
            let eb = b.categoriaManual || b.internoManual || b.notas != nil || b.ignorado
            if ea != eb { return ea }
            return a.criadoEm < b.criadoEm
        }
        try limpar(Conta.self, chave: { $0.externalID }) { a, b in
            if (a.apelido != nil) != (b.apelido != nil) { return a.apelido != nil }
            return a.atualizadaEm > b.atualizadaEm
        }
        try limpar(Conexao.self, chave: { $0.itemID }) { $0.criadaEm < $1.criadaEm }
        try limpar(Investimento.self, chave: { $0.externalID }) { $0.atualizadoEm > $1.atualizadoEm }
        try limpar(Fatura.self, chave: { $0.externalID }) { $0.atualizadaEm > $1.atualizadaEm }
        try limpar(Emprestimo.self, chave: { $0.externalID }) { $0.atualizadoEm > $1.atualizadoEm }
        try limpar(Orcamento.self, chave: { $0.categoriaChave }) { $0.atualizadoEm > $1.atualizadoEm }
        try limpar(Regra.self, chave: { $0.padrao }) { $0.criadaEm > $1.criadaEm }
        try limpar(MapaCartao.self, chave: { $0.nomeCarteira }) { $0.contaID > $1.contaID }
        try limpar(FotoPatrimonio.self, chave: { String(Int($0.dia.timeIntervalSince1970 / 86_400)) }) { $0.liquidoCentavos > $1.liquidoCentavos }

        if removidos > 0 { try contexto.save() }
        return removidos
    }
}
