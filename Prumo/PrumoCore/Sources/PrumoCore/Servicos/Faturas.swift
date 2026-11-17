import Foundation

/// Em que dia uma compra no cartão sai da conta de verdade.
public enum Faturas {
    /// A fatura cuja janela (fechamento anterior, fechamento] contém a compra manda o vencimento.
    /// Sem fatura conhecida para o período, repete o ciclo do cartão (dia de fechamento e dia de vencimento)
    /// mês a mês. `nil` quando não se sabe nada do ciclo.
    public static func dataDeDebito(compra: Date, conta: Conta, faturas: [Fatura]) -> Date? {
        let compraDia = Datas.inicioDoDia(compra)
        let pares = faturas
            .filter { $0.contaID == conta.externalID }
            .compactMap { f in f.fechamento.map { (fechamento: $0, vencimento: f.vencimento) } }
            .sorted { $0.fechamento < $1.fechamento }

        for (i, par) in pares.enumerated() {
            let anterior = i > 0 ? pares[i - 1].fechamento : Datas.somar(meses: -1, a: par.fechamento)
            if compraDia > Datas.inicioDoDia(anterior) && compraDia <= Datas.inicioDoDia(par.fechamento) {
                return par.vencimento
            }
        }

        guard let ciclo = ciclo(conta, pares.last) else { return nil }
        var fechamento = data(dia: ciclo.fechamento, noMesDe: compra)
        if Datas.inicioDoDia(fechamento) < compraDia {
            fechamento = data(dia: ciclo.fechamento, noMesDe: Datas.somar(meses: 1, a: Datas.inicioDoMes(compra)))
        }
        var vencimento = data(dia: ciclo.vencimento, noMesDe: fechamento)
        if Datas.inicioDoDia(vencimento) <= Datas.inicioDoDia(fechamento) {
            vencimento = data(dia: ciclo.vencimento, noMesDe: Datas.somar(meses: 1, a: Datas.inicioDoMes(fechamento)))
        }
        return vencimento
    }

    /// Dia de fechamento e de vencimento: do cartão, ou da última fatura que o banco mandou.
    private static func ciclo(_ conta: Conta, _ ultimaFatura: (fechamento: Date, vencimento: Date)?) -> (fechamento: Int, vencimento: Int)? {
        let cal = Datas.calendario
        if let f = conta.fechamentoFatura, let v = conta.vencimentoFatura {
            return (cal.component(.day, from: f), cal.component(.day, from: v))
        }
        if let u = ultimaFatura {
            return (cal.component(.day, from: u.fechamento), cal.component(.day, from: u.vencimento))
        }
        return nil
    }

    /// O dia pedido dentro do mês da referência, ao meio-dia; dia 31 em mês curto vira o último dia.
    static func data(dia: Int, noMesDe referencia: Date) -> Date {
        let cal = Datas.calendario
        let inicio = Datas.inicioDoMes(referencia)
        let ultimo = cal.range(of: .day, in: .month, for: inicio)?.count ?? 28
        var c = cal.dateComponents([.year, .month], from: inicio)
        c.day = min(max(1, dia), ultimo)
        c.hour = 12
        return cal.date(from: c) ?? inicio
    }
}
