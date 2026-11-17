import Foundation
import SwiftData

/// Entrada em tempo real: o Atalhos do iPhone chama isto a cada compra no Apple Pay.
public enum Carteira {

    public enum Resultado: Sendable, Equatable {
        case registrado(tituloLancamento: String, valorCentavos: Int)
        case duplicado
        case valorInvalido(String)
    }

    /// Registra um gasto vindo da Carteira. Ignora o mesmo toque repetido (o gatilho às vezes dispara 2x).
    @discardableResult
    public static func registrar(_ ctx: ModelContext,
                                 valorTexto: String,
                                 estabelecimento: String,
                                 cartao: String,
                                 agora: Date = Date()) throws -> Resultado {
        guard let centavos = Dinheiro.ler(valorTexto), centavos > 0 else { return .valorInvalido(valorTexto) }
        let bruto = valorTexto.trimmingCharacters(in: .whitespaces)
        let ehEstorno = bruto.hasPrefix("-") || bruto.hasPrefix("−")
        let maiuscula = bruto.uppercased()
        let ehEstrangeira = (bruto.contains("$") && !maiuscula.contains("R$")) || bruto.contains("€")
            || maiuscula.contains("USD") || maiuscula.contains("EUR") || maiuscula.contains("GBP")
        let nome = estabelecimento.trimmingCharacters(in: .whitespacesAndNewlines)
        let descricao = nome.isEmpty ? "Compra no Apple Pay" : nome

        // Mesma compra em menos de 45 s = toque repetido (duas corridas iguais costumam ter mais intervalo).
        let origem = OrigemLancamento.carteira.rawValue
        let corte = agora.addingTimeInterval(-45)
        let recentes = try ctx.fetch(FetchDescriptor<Lancamento>(
            predicate: #Predicate { $0.origemRaw == origem && $0.criadoEm >= corte }
        ))
        let alvo = ehEstorno ? centavos : -centavos
        if recentes.contains(where: { $0.valorCentavos == alvo && Texto.normalizar($0.descricao) == Texto.normalizar(descricao) }) {
            return .duplicado
        }

        let conta = try contaDoCartao(ctx, nomeNaCarteira: cartao)
        let regras = try ctx.fetch(FetchDescriptor<Regra>())
        let cat = Categorizador.categorizar(descricao: descricao, estabelecimento: nome, valorCentavos: alvo,
                                            ehCartao: conta?.tipo.ehCartao ?? true, regras: regras)

        // O toque aconteceu agora: guarda o dia local, ao meio-dia (mesma convenção dos lançamentos do banco).
        let dia = Datas.calendario.date(bySettingHour: 12, minute: 0, second: 0, of: agora) ?? agora
        let l = Lancamento(externalID: "carteira-\(UUID().uuidString)", contaID: conta?.externalID ?? "",
                           data: dia, descricao: descricao, valorCentavos: alvo, origem: .carteira)
        l.estabelecimento = nome.isEmpty ? nil : nome
        l.categoriaChave = ehEstorno ? "reembolsos" : cat.chave
        l.interno = ehEstorno ? false : cat.interno
        if ehEstrangeira {
            l.notas = "Compra em moeda estrangeira (\(bruto)). O valor em reais será corrigido quando o banco lançar."
        }
        l.cartaoCarteira = cartao
        l.criadoEm = agora
        ctx.insert(l)
        try ctx.save()
        try Conciliador.conciliar(ctx)
        return .registrado(tituloLancamento: descricao, valorCentavos: alvo)
    }

    /// Descobre a conta do app a partir do nome do cartão na Carteira ("Nubank Mastercard ••1234").
    static func contaDoCartao(_ ctx: ModelContext, nomeNaCarteira: String) throws -> Conta? {
        let alvo = nomeNaCarteira.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alvo.isEmpty else { return nil }
        let mapas = try ctx.fetch(FetchDescriptor<MapaCartao>())
        let contas = try ctx.fetch(FetchDescriptor<Conta>())
        let nAlvo = Texto.normalizar(alvo)
        let porMapa = mapas.first { Texto.normalizar($0.nomeCarteira) == nAlvo }
            ?? mapas.first {
                let n = Texto.normalizar($0.nomeCarteira)
                return n.count >= 4 && (nAlvo.contains(n) || n.contains(nAlvo))
            }
        if let m = porMapa, let c = contas.first(where: { $0.externalID == m.contaID }) { return c }

        // Heurística: final do cartão (últimos 4 dígitos) e/ou nome da instituição.
        let digitos = alvo.filter(\.isNumber)
        let final4 = digitos.count >= 4 ? String(digitos.suffix(4)) : nil
        let cartoes = contas.filter { $0.tipo.ehCartao && !$0.arquivada }
        if let f = final4, let c = cartoes.first(where: { $0.final4 == f }) { return c }
        let n = Texto.normalizar(alvo)
        let porNome = cartoes.filter { c in
            let inst = Texto.normalizar(c.instituicao)
            return !inst.isEmpty && n.contains(inst)
        }
        if porNome.count == 1 { return porNome[0] }
        return nil
    }
}
