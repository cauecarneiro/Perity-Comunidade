import Foundation
import SwiftData

/// Gerador determinístico (mesma semente = mesmos dados), para a demonstração e para os testes.
struct GeradorAleatorio: RandomNumberGenerator {
    private var estado: UInt64
    init(semente: UInt64) { estado = semente }
    mutating func next() -> UInt64 {
        estado &+= 0x9E37_79B9_7F4A_7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Uma vida financeira fictícia, mas realista, para o app mostrar tudo funcionando antes de você conectar os bancos.
/// Tudo que nasce aqui é marcado como demonstração e pode ser apagado com `limpar`.
public enum DadosDemo {
    public static let prefixo = "demo-"

    // MARK: Limpeza

    public static func limpar(_ ctx: ModelContext) throws {
        func apagar<T: PersistentModel>(_ tipo: T.Type, onde ehDemo: (T) -> Bool) throws {
            for item in try ctx.fetch(FetchDescriptor<T>()) where ehDemo(item) { ctx.delete(item) }
        }
        try apagar(Conexao.self) { $0.demo }
        try apagar(Conta.self) { $0.externalID.hasPrefix(prefixo) }
        try apagar(Lancamento.self) { $0.externalID.hasPrefix(prefixo) }
        try apagar(Fatura.self) { $0.externalID.hasPrefix(prefixo) }
        try apagar(Investimento.self) { $0.externalID.hasPrefix(prefixo) }
        try apagar(Emprestimo.self) { $0.externalID.hasPrefix(prefixo) }
        try apagar(Orcamento.self) { $0.demo }
        try apagar(Meta.self) { $0.demo }
        try apagar(FotoPatrimonio.self) { $0.demo }
        try apagar(MapaCartao.self) { $0.contaID.hasPrefix(prefixo) }
        try apagar(Fixo.self) { $0.demo }
        try apagar(MarcaFixo.self) { $0.demo }
        try ctx.save()
    }

    public static func existe(_ ctx: ModelContext) -> Bool {
        let n = (try? ctx.fetchCount(FetchDescriptor<Conexao>(predicate: #Predicate { $0.demo }))) ?? 0
        return n > 0
    }

    /// CDI fictício para a demonstração funcionar sem internet: cerca de 1,1% ao mês nos últimos 20 meses.
    public static func cdiDeExemplo(hoje: Date = Date()) -> TabelaCDI {
        let taxas = [0.0108, 0.0109, 0.0122, 0.0112, 0.0107, 0.0109, 0.0121, 0.0100, 0.0116, 0.0122, 0.0105, 0.0128]
        var porMes: [String: Double] = [:]
        let inicio = Datas.inicioDoMes(hoje)
        porMes[Fixos.chaveMes(inicio)] = 0.0036
        for i in 1...20 {
            porMes[Fixos.chaveMes(Datas.somar(meses: -i, a: inicio))] = taxas[(i - 1) % taxas.count]
        }
        return TabelaCDI(porMes: porMes, buscadoEm: hoje)
    }

    // MARK: Geração

    // swiftlint:disable:next function_body_length
    public static func popular(_ ctx: ModelContext, hoje: Date = Date(), semente: UInt64 = 2026) throws {
        try limpar(ctx)
        var rng = GeradorAleatorio(semente: semente)
        let cal = Datas.calendario
        let hojeInicio = Datas.inicioDoDia(hoje)

        func dia(_ mesesAtras: Int, _ d: Int) -> Date {
            let base = Datas.somar(meses: -mesesAtras, a: Datas.inicioDoMes(hoje))
            let max = cal.range(of: .day, in: .month, for: base)?.count ?? 28
            var c = cal.dateComponents([.year, .month], from: base)
            c.day = min(d, max)
            c.hour = 12
            return cal.date(from: c) ?? base
        }
        func sorteio(_ r: ClosedRange<Int>) -> Int { Int.random(in: r, using: &rng) }
        func reais(_ r: ClosedRange<Int>) -> Int { sorteio(r) * 100 + [0, 90, 50, 70, 99, 10].randomElement(using: &rng)! }

        // Conexões
        let azul = Conexao(itemID: "\(prefixo)azul", nome: "Banco Azul", demo: true)
        azul.corHex = "0C47F9"; azul.status = "UPDATED"; azul.ultimaAtualizacao = hoje.addingTimeInterval(-6 * 3600)
        azul.proximaAtualizacao = hoje.addingTimeInterval(18 * 3600)
        azul.consentimentoExpiraEm = Datas.somar(dias: 9, a: hoje)
        let laranja = Conexao(itemID: "\(prefixo)laranja", nome: "Banco Laranja", demo: true)
        laranja.corHex = "FF7A45"; laranja.status = "UPDATED"; laranja.ultimaAtualizacao = hoje.addingTimeInterval(-6 * 3600)
        laranja.proximaAtualizacao = hoje.addingTimeInterval(18 * 3600)
        let verde = Conexao(itemID: "\(prefixo)verde", nome: "Corretora Verde", demo: true)
        verde.corHex = "17B26A"; verde.status = "UPDATED"; verde.ultimaAtualizacao = hoje.addingTimeInterval(-6 * 3600)
        verde.proximaAtualizacao = hoje.addingTimeInterval(18 * 3600)
        [azul, laranja, verde].enumerated().forEach { $1.ordem = $0; ctx.insert($1) }

        // Contas
        func conta(_ id: String, _ nome: String, _ tipo: TipoConta, _ cx: Conexao, saldo: Int, ordem: Int) -> Conta {
            let c = Conta(externalID: prefixo + id, nome: nome, tipo: tipo, instituicao: cx.nome)
            c.conexaoItemID = cx.itemID
            c.corHex = cx.corHex
            c.saldoCentavos = saldo
            c.ordem = ordem
            ctx.insert(c)
            return c
        }
        let azulCC = conta("azul-cc", "Conta corrente", .corrente, azul, saldo: 482_037, ordem: 0)
        let azulPoup = conta("azul-poup", "Poupança", .poupanca, azul, saldo: 1_230_000, ordem: 1)
        let azulCartao = conta("azul-cartao", "Azul Platinum", .cartao, azul, saldo: 0, ordem: 2)
        azulCartao.limiteCentavos = 1_200_000; azulCartao.bandeira = "Visa"; azulCartao.final4 = "4821"
        let laranjaCC = conta("laranja-cc", "Conta digital", .corrente, laranja, saldo: 115_042, ordem: 3)
        let laranjaCartao = conta("laranja-cartao", "Cartão Laranja", .cartao, laranja, saldo: 0, ordem: 4)
        laranjaCartao.limiteCentavos = 450_000; laranjaCartao.bandeira = "Mastercard"; laranjaCartao.final4 = "9035"
        let verdeCC = conta("verde-cc", "Saldo na corretora", .investimento, verde, saldo: 38_000, ordem: 5)
        _ = verdeCC

        // Lançamentos
        var todos: [Lancamento] = []
        var n = 0
        func lancar(_ conta: Conta, _ data: Date, _ desc: String, _ valor: Int, estab: String? = nil,
                    pendente: Bool = false, parcela: (Int, Int)? = nil, origem: OrigemLancamento = .demo,
                    cartaoCarteira: String? = nil) {
            n += 1
            let l = Lancamento(externalID: "\(prefixo)l\(n)", contaID: conta.externalID, data: data, descricao: desc,
                               valorCentavos: valor, origem: origem)
            l.estabelecimento = estab
            l.status = pendente ? .pendente : .efetivado
            l.parcelaAtual = parcela?.0
            l.totalParcelas = parcela?.1
            l.cartaoCarteira = cartaoCarteira
            let r = Categorizador.categorizar(descricao: desc, estabelecimento: estab, valorCentavos: valor, ehCartao: conta.tipo.ehCartao)
            l.categoriaChave = r.chave
            var interno = r.interno
            if conta.tipo.ehCartao, valor > 0, r.chave != "reembolsos" { interno = true; l.categoriaChave = "fatura" }
            l.interno = interno
            l.criadoEm = data
            l.atualizadoEm = data
            ctx.insert(l)
            todos.append(l)
        }

        let meses = 6
        for m in stride(from: meses, through: 0, by: -1) {
            let futuroDoMes: (Date) -> Bool = { $0 > hojeInicio }
            func entrar(_ c: Conta, _ d: Date, _ desc: String, _ v: Int, estab: String? = nil, parcela: (Int, Int)? = nil) {
                // Não inventa o futuro: só o que já aconteceu (parcelas futuras ficam como pendentes).
                if futuroDoMes(d) && parcela == nil { return }
                lancar(c, d, desc, v, estab: estab, pendente: futuroDoMes(d), parcela: parcela)
            }

            // Renda
            entrar(azulCC, dia(m, 5), "SALARIO EMPRESA XYZ LTDA", 1_000_000)
            if m % 2 == 0 { entrar(laranjaCC, dia(m, 18 + sorteio(0...6)), "PIX RECEBIDO CLIENTE DESIGN", reais(900...3_200)) }
            if m == 4 { entrar(azulCC, dia(m, 20), "13O SALARIO PARCELA", 490_000) }
            entrar(azulCC, dia(m, 28), "RENDIMENTOS POUPANCA", reais(60...110))

            // Moradia e contas
            entrar(azulCC, dia(m, 8), "ALUGUEL IMOBILIARIA CENTRAL", -250_000)
            entrar(azulCC, dia(m, 8), "CONDOMINIO EDIFICIO PARQUE", -70_000)
            entrar(azulCC, dia(m, 15), "ENEL DISTRIBUICAO ENERGIA", -reais(160...290))
            entrar(azulCartao, dia(m, 12), "VERO INTERNET FIBRA", -11_990)
            entrar(azulCartao, dia(m, 20), "CLARO CELULAR POS", -8_990)

            // Assinaturas (com um reajuste recente)
            entrar(azulCartao, dia(m, 10), "NETFLIX.COM", -5_590)
            entrar(azulCartao, dia(m, 14), "SPOTIFY", -2_390)
            entrar(azulCartao, dia(m, 3), "APPLE.COM/BILL ICLOUD", -1_490)
            entrar(azulCartao, dia(m, 22), "OPENAI *CHATGPT SUBSCR", m <= 1 ? -12_900 : -10_900)
            entrar(azulCartao, dia(m, 2), "SMART FIT ACADEMIA", -11_990)

            // Mercado
            for semana in 0..<4 {
                let loja = ["CARREFOUR HIPER", "PAO DE ACUCAR", "ASSAI ATACADISTA", "HORTIFRUTI NATURAL"][semana % 4]
                entrar(semana % 2 == 0 ? azulCartao : azulCC, dia(m, 3 + semana * 7 + sorteio(0...2)), "COMPRA NO DEBITO - \(loja)", -reais(110...420))
            }
            // Restaurantes e delivery
            for _ in 0..<(12 + sorteio(0...6)) {
                let lugar = ["IFOOD *RESTAURANTE", "IFOOD *PIZZARIA", "MCDONALDS", "OUTBACK STEAKHOUSE", "STARBUCKS", "PADARIA PAO QUENTE", "RAPPI*LANCHONETE", "SUSHI HOUSE"].randomElement(using: &rng)!
                entrar(Bool.random(using: &rng) ? azulCartao : laranjaCartao, dia(m, 1 + sorteio(0...27)), lugar, -reais(24...135))
            }
            // Transporte
            for _ in 0..<(8 + sorteio(0...5)) {
                entrar(laranjaCartao, dia(m, 1 + sorteio(0...27)), "UBER *TRIP", -reais(13...52))
            }
            for s in 0..<3 { entrar(azulCartao, dia(m, 4 + s * 9), "POSTO SHELL AV BRASIL", -reais(170...260)) }
            // Saúde
            for _ in 0..<(1 + sorteio(0...2)) { entrar(azulCartao, dia(m, 1 + sorteio(0...27)), "DROGASIL 1234", -reais(28...190)) }
            if m % 3 == 0 { entrar(azulCC, dia(m, 16), "CLINICA SAO LUCAS CONSULTA", -25_000) }
            // Lazer
            for _ in 0..<(2 + sorteio(0...3)) {
                let lugar = ["CINEMARK ING", "BAR DO ZE BOTECO", "SYMPLA INGRESSOS", "STEAM GAMES"].randomElement(using: &rng)!
                entrar(laranjaCartao, dia(m, 1 + sorteio(0...27)), lugar, -reais(35...220))
            }
            // Compras
            for _ in 0..<(1 + sorteio(0...3)) {
                let loja = ["MERCADOLIVRE*VENDEDOR", "AMAZON BR", "SHEIN", "RENNER", "KABUM"].randomElement(using: &rng)!
                entrar(Bool.random(using: &rng) ? azulCartao : laranjaCartao, dia(m, 1 + sorteio(0...27)), loja, -reais(55...480))
            }
            if m == 3 {
                entrar(azulCartao, dia(m, 9), "LATAM AIRLINES BRASIL", -142_000)
                entrar(azulCartao, dia(m, 12), "HOTEL ATLANTICO BOOKING", -98_000)
            }
            // Parcelas do notebook (10x)
            let parcelaN = 4 - m + 1
            if parcelaN >= 1 && parcelaN <= 10 {
                entrar(azulCartao, dia(m, 6), "APPLE STORE NOTEBOOK PARC \(parcelaN)/10", -48_990, parcela: (parcelaN, 10))
            }
            // Aportes (não são gasto nem renda)
            entrar(azulCC, dia(m, 6), "APLICACAO CDB", -150_000)
            if m == 2 { entrar(azulCC, dia(m, 21), "ESTORNO COMPRA MERCADOLIVRE", 15_990) }
            if m == 5 { entrar(azulCC, dia(m, 22), "IPVA 2026 DETRAN", -138_000) }
            // Carro, bar e roupa (valores fixos: não mexem no sorteio dos outros meses)
            entrar(azulCartao, dia(m, 11), "ESTAPAR ESTACIONAMENTO", -2_400)
            entrar(azulCartao, dia(m, 9), "LAVA RAPIDO JET WASH", -6_000)
            entrar(laranjaCartao, dia(m, 7), "CERVEJARIA DO PORTO", -8_900)
            if m == 1 { entrar(azulCartao, dia(m, 17), "AUTO CENTER OFICINA REVISAO", -68_000) }
            if m % 2 == 1 { entrar(laranjaCartao, dia(m, 13), "NIKE STORE", -39_990) }
        }

        // Lançamentos "ao vivo" do Apple Pay (ainda não confirmados pelo banco)
        lancar(azulCartao, hoje, "PADARIA PAO QUENTE", -1_890, estab: "Padaria Pão Quente", origem: .carteira, cartaoCarteira: "Azul Platinum ••4821")
        lancar(azulCartao, hoje.addingTimeInterval(-3600 * 2), "UBER *TRIP", -2_340, estab: "Uber", origem: .carteira, cartaoCarteira: "Azul Platinum ••4821")
        lancar(azulCartao, Datas.somar(dias: -1, a: hoje), "STARBUCKS", -2_700, estab: "Starbucks", origem: .carteira, cartaoCarteira: "Azul Platinum ••4821")

        // Um gasto que o Apple Pay avisou primeiro e o banco confirmou depois: aparece uma vez só.
        lancar(laranjaCartao, Datas.somar(dias: -3, a: hoje), "CAFE DO CENTRO", -3_450, estab: "Café do Centro", origem: .carteira)
        lancar(laranjaCartao, Datas.somar(dias: -2, a: hoje), "CAFE DO CENTRO LTDA", -3_450, origem: .openFinance)

        // Cartões: ciclos relativos a hoje, para o painel sempre ter uma fatura próxima.
        // Azul: fechou há 4 dias, vence em 3. Laranja: fechou há 20 dias (já paga), fecha de novo em ~10.
        func meioDia(_ d: Date) -> Date { cal.date(bySettingHour: 12, minute: 0, second: 0, of: d) ?? d }
        struct Ciclo { let fechamentoRecente: Date }
        func fechamento(_ c: Ciclo, _ k: Int) -> Date { meioDia(Datas.somar(meses: -k, a: c.fechamentoRecente)) }
        func vencimento(_ c: Ciclo, _ k: Int) -> Date { Datas.somar(dias: 7, a: fechamento(c, k)) }

        let cicloAzul = Ciclo(fechamentoRecente: meioDia(Datas.somar(dias: -4, a: hojeInicio)))
        let cicloLaranja = Ciclo(fechamentoRecente: meioDia(Datas.somar(dias: -20, a: hojeInicio)))

        func totalDoCiclo(_ c: Conta, _ ciclo: Ciclo, _ k: Int) -> Int {
            let ini = fechamento(ciclo, k + 1), fim = fechamento(ciclo, k)
            return todos
                .filter { $0.contaID == c.externalID && $0.data > ini && $0.data <= fim && $0.valorCentavos < 0 && $0.origem == .demo }
                .reduce(0) { $0 + (-$1.valorCentavos) }
        }

        func faturasDoCartao(_ c: Conta, _ banco: Conta, _ ciclo: Ciclo, idFatura: String, nomeCartao: String) -> Int {
            var devidoEmAberto = 0
            for k in 0...4 {
                let total = totalDoCiclo(c, ciclo, k)
                let venc = vencimento(ciclo, k)
                let f = Fatura(externalID: "\(prefixo)\(idFatura)-\(k)", contaID: c.externalID, vencimento: venc, totalCentavos: total)
                f.fechamento = fechamento(ciclo, k)
                f.minimoCentavos = total / 7
                let paga = venc <= hojeInicio
                f.pagaCentavos = paga ? total : 0
                ctx.insert(f)
                if paga {
                    lancar(banco, venc, "PAGAMENTO DE FATURA \(nomeCartao)", -total)
                    // O cartão está no app, então o débito é o par do "pagamento recebido": não é gasto de novo
                    // (na conexão real, quem faz isso é `Conciliador.parearFaturas`).
                    todos.last?.interno = true
                    lancar(c, venc, "PAGAMENTO RECEBIDO", total)
                } else {
                    devidoEmAberto += total
                }
            }
            return devidoEmAberto
        }

        func estadoDoCartao(_ c: Conta, _ ciclo: Ciclo, faturado: Int) {
            let fechou = fechamento(ciclo, 0)
            let aberta = todos
                .filter { $0.contaID == c.externalID && $0.data > fechou && $0.valorCentavos < 0 && $0.origem != .openFinance }
                .reduce(0) { $0 + (-$1.valorCentavos) }
            c.saldoCentavos = aberta + faturado
            c.disponivelCentavos = max(0, (c.limiteCentavos ?? 0) - c.saldoCentavos)
            c.fechamentoFatura = fechamento(ciclo, -1)
            c.vencimentoFatura = faturado > 0 ? vencimento(ciclo, 0) : vencimento(ciclo, -1)
            c.minimoFaturaCentavos = c.saldoCentavos / 7
        }

        let faturadoAzul = faturasDoCartao(azulCartao, azulCC, cicloAzul, idFatura: "fat-azul", nomeCartao: "AZUL PLATINUM")
        let faturadoLaranja = faturasDoCartao(laranjaCartao, laranjaCC, cicloLaranja, idFatura: "fat-laranja", nomeCartao: "CARTAO LARANJA")
        estadoDoCartao(azulCartao, cicloAzul, faturado: faturadoAzul)
        estadoDoCartao(laranjaCartao, cicloLaranja, faturado: faturadoLaranja)

        // Investimentos
        func inv(_ id: String, _ nome: String, _ classe: ClasseAtivo, _ cx: Conexao, saldo: Int, aplicado: Int,
                 taxa: Double? = nil, r12: Double? = nil, rMes: Double? = nil, venc: Date? = nil, emissor: String? = nil,
                 codigo: String? = nil, qtd: Double? = nil, cota: Int? = nil, manual: Bool = false, subtipo: String? = nil) {
            let i = Investimento(externalID: prefixo + id, nome: nome, classe: classe, saldoCentavos: saldo)
            i.conexaoItemID = cx.itemID
            i.instituicao = cx.nome
            i.aplicadoCentavos = aplicado
            i.taxaAnual = taxa
            i.rentabilidade12m = r12
            i.rentabilidadeMes = rMes ?? r12.map { pow(1 + $0, 1.0 / 12) - 1 }
            i.vencimento = venc
            i.emissor = emissor
            i.codigo = codigo
            i.quantidade = qtd
            i.valorCotaCentavos = cota
            i.manual = manual
            i.subtipo = subtipo
            ctx.insert(i)
        }
        // Taxas coerentes com um CDI perto de 1,1% ao mês (14% em 12 meses), para a comparação fazer sentido.
        inv("tesouro-selic", "Tesouro Selic 2029", .tesouro, verde, saldo: 1_842_055, aplicado: 1_650_000, taxa: 0.1490, r12: 0.1418, rMes: 0.0108,
            venc: Datas.somar(meses: 29, a: hoje), emissor: "Tesouro Nacional", subtipo: "TREASURY")
        inv("cdb-azul", "CDB Banco Azul 110% CDI", .rendaFixa, azul, saldo: 2_587_012, aplicado: 2_400_000, taxa: 0.1640, r12: 0.1571, rMes: 0.0119,
            venc: Datas.somar(meses: 11, a: hoje), emissor: "Banco Azul", subtipo: "CDB")
        inv("lci", "LCI 95% CDI", .rendaFixa, azul, saldo: 1_054_000, aplicado: 1_000_000, taxa: 0.1415, r12: 0.1352, rMes: 0.0103,
            venc: Datas.somar(dias: 22, a: hoje), emissor: "Banco Azul", subtipo: "LCI")
        inv("multimercado", "Fundo Multimercado Horizonte", .fundos, verde, saldo: 812_040, aplicado: 750_000, r12: 0.1173, rMes: 0.0071)
        inv("petr4", "Petrobras PN", .acoes, verde, saldo: 460_800, aplicado: 396_000, r12: 0.2140, rMes: 0.0312, codigo: "PETR4", qtd: 120, cota: 3_840, subtipo: "STOCK")
        inv("itub4", "Itaú Unibanco PN", .acoes, verde, saldo: 663_000, aplicado: 610_000, r12: 0.1520, rMes: 0.0164, codigo: "ITUB4", qtd: 200, cota: 3_315, subtipo: "STOCK")
        inv("wege3", "WEG ON", .acoes, verde, saldo: 260_500, aplicado: 285_000, r12: -0.0860, rMes: -0.0240, codigo: "WEGE3", qtd: 50, cota: 5_210, subtipo: "STOCK")
        inv("hglg11", "CSHG Logística", .fiis, verde, saldo: 474_900, aplicado: 468_000, r12: 0.0920, rMes: 0.0062, codigo: "HGLG11", qtd: 30, cota: 15_830, subtipo: "REAL_ESTATE_FUND")
        inv("xpml11", "XP Malls", .fiis, verde, saldo: 490_050, aplicado: 481_500, r12: 0.1105, rMes: 0.0094, codigo: "XPML11", qtd: 45, cota: 10_890, subtipo: "REAL_ESTATE_FUND")
        inv("ivvb11", "iShares S&P 500", .etfs, verde, saldo: 1_382_400, aplicado: 1_150_000, r12: 0.1980, rMes: 0.0145, codigo: "IVVB11", qtd: 40, cota: 34_560, subtipo: "ETF")
        inv("vgbl", "Previdência VGBL", .previdencia, azul, saldo: 980_000, aplicado: 900_000, r12: 0.1090, rMes: 0.0082, subtipo: "VGBL")
        inv("btc", "Bitcoin", .cripto, verde, saldo: 735_000, aplicado: 520_000, codigo: "BTC", qtd: 0.0215, manual: true)

        // Empréstimo
        let emp = Emprestimo(externalID: "\(prefixo)estudantil", nome: "Financiamento estudantil", contratadoCentavos: 2_400_000)
        emp.instituicao = "Banco Laranja"; emp.conexaoItemID = laranja.itemID
        emp.parcelaCentavos = 61_200; emp.parcelasRestantes = 28; emp.saldoDevedorCentavos = 61_200 * 28
        emp.proximoVencimento = dia(0, 20) >= hojeInicio ? dia(0, 20) : dia(-1, 20)
        emp.vencimentoFinal = Datas.somar(meses: 28, a: hoje)
        emp.custoEfetivoTotal = 0.0912
        ctx.insert(emp)

        // Orçamentos
        let orcs: [(String, Int)] = [("aluguel", 250_000), ("mercado", 160_000), ("delivery", 60_000), ("combustivel", 70_000),
                                     ("lazer", 50_000), ("streaming", 10_000), ("compras", 80_000), ("farmacia", 30_000)]
        for (chave, valor) in orcs {
            let o = Orcamento(categoriaChave: chave, valorCentavos: valor)
            o.demo = true
            ctx.insert(o)
        }
        // Metas
        let metas: [(String, Int, Int, Int?, String, String)] = [
            ("Reserva de emergência", 6_000_000, 3_800_000, nil, "shield.fill", "17B26A"),
            ("Viagem ao Japão", 2_200_000, 950_000, 10, "airplane", "0C47F9"),
            ("Entrada do apartamento", 8_000_000, 1_250_000, 30, "house.fill", "FF7A45"),
        ]
        for (nome, alvo, guardado, prazoMeses, icone, cor) in metas {
            let m = Meta(nome: nome, alvoCentavos: alvo, guardadoCentavos: guardado, prazo: prazoMeses.map { Datas.somar(meses: $0, a: hoje) })
            m.icone = icone; m.corHex = cor; m.demo = true
            ctx.insert(m)
        }
        // Gastos fixos do mês (a lista com caixinha de "pago")
        let fixosDemo: [(String, Int, FormaPagamento, String, String, Bool)] = [
            ("Aluguel", 250_000, .boleto, "aluguel", "aluguel imobiliaria", false),
            ("Condomínio", 70_000, .boleto, "condominio", "condominio", false),
            ("Luz", 22_000, .debito, "luz", "enel", false),
            ("Internet", 11_990, .cartao, "internet", "vero internet", false),
            ("Celular", 8_990, .cartao, "celular", "claro", false),
            ("Mercado", 160_000, .cartao, "mercado", "", true),
            ("Gasolina", 70_000, .cartao, "combustivel", "", true),
            ("Academia", 11_990, .cartao, "academia", "smart fit", false),
            ("Notebook 10x", 48_990, .cartao, "eletronicos", "apple store notebook", false),
            ("Netflix", 5_590, .cartao, "streaming", "netflix", false),
            ("Spotify", 2_390, .cartao, "streaming", "spotify", false),
            ("ChatGPT", 12_900, .cartao, "apps_ia", "openai, chatgpt", false),
            ("iCloud", 1_490, .cartao, "apps_ia", "icloud", false),
            ("Faxina", 40_000, .pix, "moradia", "faxina diarista", false),
            ("Plano de saúde", 38_900, .boleto, "plano_saude", "plano saude unimed", false),
        ]
        for (i, (nome, valor, forma, cat, padrao, acumula)) in fixosDemo.enumerated() {
            let f = Fixo(nome: nome, valorCentavos: valor, forma: forma, categoriaChave: cat, padrao: padrao, acumula: acumula)
            f.uid = "\(prefixo)fixo-\(i)"
            f.ordem = i
            f.demo = true
            ctx.insert(f)
            if nome == "Faxina" {
                // Pago por Pix e marcado à mão.
                let marca = MarcaFixo(fixoUID: f.uid, mes: Fixos.chaveMes(hoje), pago: true)
                marca.demo = true
                ctx.insert(marca)
            }
        }

        // Mapeamento do cartão da Carteira
        ctx.insert(MapaCartao(nomeCarteira: "Azul Platinum ••4821", contaID: azulCartao.externalID))

        // Evolução do patrimônio (180 dias)
        let atual = Patrimonio.calcular(contas: [azulCC, azulPoup, azulCartao, laranjaCC, laranjaCartao],
                                        investimentos: (try? ctx.fetch(FetchDescriptor<Investimento>())) ?? [],
                                        emprestimos: [emp])
        let liquidoHoje = atual.liquidoCentavos + 38_000
        for i in stride(from: 180, through: 0, by: -3) {
            let d = Datas.somar(dias: -i, a: hojeInicio)
            let progresso = 1.0 - Double(i) / 180.0
            let tendencia = Double(liquidoHoje) * (0.82 + 0.18 * progresso)
            let ruido = Double(sorteio(-90_000...90_000))
            let liquido = Int(tendencia + ruido)
            let investido = Int(Double(atual.investidoCentavos) * (0.80 + 0.20 * progresso))
            let f = FotoPatrimonio(dia: d, disponivelCentavos: liquido - investido + atual.dividasCentavos,
                                   investidoCentavos: investido, dividasCentavos: atual.dividasCentavos)
            f.liquidoCentavos = liquido
            f.demo = true
            ctx.insert(f)
        }

        try ctx.save()
        try Conciliador.conciliar(ctx)
    }
}
