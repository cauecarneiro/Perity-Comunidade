import Foundation

/// Resumo pequeno que o app grava para os widgets lerem (widgets não abrem o banco de dados).
public struct SnapshotWidget: Codable, Equatable, Sendable {
    public static var grupo: String { Identidade.grupoApp }
    private static let chave = "prumo.snapshotWidget"

    public var gerado: Date
    public var liquidoCentavos: Int
    public var gastoMesCentavos: Int
    public var receitaMesCentavos: Int
    public var previsaoMesCentavos: Int
    public var mediaMensalCentavos: Int
    public var proximaFaturaNome: String?
    public var proximaFaturaData: Date?
    public var proximaFaturaCentavos: Int?
    public var ocultarValores: Bool
    public var demo: Bool
    // Campos novos são opcionais: um resumo gravado por uma versão antiga continua abrindo.
    public var saldoContasCentavos: Int?
    public var faturasCentavos: Int?
    public var fixosFaltaCentavos: Int?
    public var fixosPagos: Int?
    public var fixosQuantidade: Int?

    public init(gerado: Date, liquidoCentavos: Int, gastoMesCentavos: Int, receitaMesCentavos: Int,
                previsaoMesCentavos: Int, mediaMensalCentavos: Int, proximaFaturaNome: String? = nil,
                proximaFaturaData: Date? = nil, proximaFaturaCentavos: Int? = nil,
                ocultarValores: Bool = false, demo: Bool = false) {
        self.gerado = gerado
        self.liquidoCentavos = liquidoCentavos
        self.gastoMesCentavos = gastoMesCentavos
        self.receitaMesCentavos = receitaMesCentavos
        self.previsaoMesCentavos = previsaoMesCentavos
        self.mediaMensalCentavos = mediaMensalCentavos
        self.proximaFaturaNome = proximaFaturaNome
        self.proximaFaturaData = proximaFaturaData
        self.proximaFaturaCentavos = proximaFaturaCentavos
        self.ocultarValores = ocultarValores
        self.demo = demo
    }

    public static let exemplo = SnapshotWidget(
        gerado: Date(), liquidoCentavos: 12_480_000, gastoMesCentavos: 482_000, receitaMesCentavos: 980_000,
        previsaoMesCentavos: 910_000, mediaMensalCentavos: 880_000, proximaFaturaNome: "Cartão Azul",
        proximaFaturaData: Date().addingTimeInterval(86_400 * 3), proximaFaturaCentavos: 213_450, demo: true)
        .com(saldoContas: 1_865_079, faturas: 415_473, fixosFalta: 78_900, fixosPagos: 11, fixosQuantidade: 15)

    func com(saldoContas: Int, faturas: Int, fixosFalta: Int?, fixosPagos: Int?, fixosQuantidade: Int?) -> SnapshotWidget {
        var s = self
        s.saldoContasCentavos = saldoContas
        s.faturasCentavos = faturas
        s.fixosFaltaCentavos = fixosFalta
        s.fixosPagos = fixosPagos
        s.fixosQuantidade = fixosQuantidade
        return s
    }

    /// Calcula a partir dos dados do app.
    public static func calcular(lancamentos: [Lancamento], contas: [Conta], investimentos: [Investimento],
                                emprestimos: [Emprestimo], faturas: [Fatura], fixos: [Fixo] = [], marcas: [MarcaFixo] = [],
                                ocultarValores: Bool, demo: Bool, hoje: Date = Date()) -> SnapshotWidget {
        let p = Patrimonio.calcular(contas: contas, investimentos: investimentos, emprestimos: emprestimos)
        let mes = Analise.resumoDoMes(hoje, lancamentos: lancamentos, contas: contas, hoje: hoje)
        let prev = Analise.previsaoDoMes(lancamentos: lancamentos, contas: contas, hoje: hoje)
        let venc = Analise.proximosVencimentos(contas: contas, faturas: faturas, recorrentes: [], emprestimos: [], hoje: hoje, dias: 31)
            .first { $0.tipo == .fatura }
        let resumoFixos: ResumoFixos? = fixos.contains(where: \.ativo)
            ? Fixos.resumo(Fixos.situacao(fixos: fixos, marcas: marcas, lancamentos: lancamentos, mes: hoje)) : nil
        return SnapshotWidget(
            gerado: hoje, liquidoCentavos: p.liquidoCentavos, gastoMesCentavos: mes.despesasCentavos,
            receitaMesCentavos: mes.receitasCentavos, previsaoMesCentavos: prev.projetadoCentavos,
            mediaMensalCentavos: prev.mediaMensalCentavos, proximaFaturaNome: venc?.titulo,
            proximaFaturaData: venc?.data, proximaFaturaCentavos: venc?.valorCentavos,
            ocultarValores: ocultarValores, demo: demo)
            .com(saldoContas: p.disponivelCentavos, faturas: p.faturasCentavos,
                 fixosFalta: resumoFixos?.faltaCentavos, fixosPagos: resumoFixos?.pagos, fixosQuantidade: resumoFixos?.quantidade)
    }

    // MARK: Armazenamento no grupo do app (compartilhado com a extensão de widget)

    private static var defaults: UserDefaults { UserDefaults(suiteName: grupo) ?? .standard }

    public func gravar() {
        guard let dados = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(dados, forKey: Self.chave)
    }

    public static func ler() -> SnapshotWidget? {
        guard let dados = defaults.data(forKey: chave) else { return nil }
        return try? JSONDecoder().decode(SnapshotWidget.self, from: dados)
    }

    /// Apaga o que os widgets mostram (usado quando o app sai do modo de exemplo).
    public static func limpar() {
        defaults.removeObject(forKey: chave)
    }
}
