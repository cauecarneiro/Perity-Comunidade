import XCTest
import SwiftData
@testable import PrumoCore

/// Categorias bem divididas, destaques do mês, CDI e fechamento dos investimentos.
@MainActor
final class DetalhamentoTests: XCTestCase {
    private var container: ModelContainer!

    private func cat(_ descricao: String, banco: String? = nil) -> String {
        Categorizador.categorizar(descricao: descricao, categoriaDoBanco: banco, valorCentavos: -5_000).chave
    }

    // MARK: Categorias

    func testCarroEDividoEmGasolinaManutencaoLimpezaEstacionamentoETaxas() {
        XCTAssertEqual(cat("POSTO SHELL AV BRASIL"), "combustivel")
        XCTAssertEqual(cat("AUTO POSTO IPIRANGA"), "combustivel")
        XCTAssertEqual(cat("OFICINA DO JOAO"), "carro")
        XCTAssertEqual(cat("AUTO CENTER OFICINA REVISAO"), "carro")
        XCTAssertEqual(cat("LAVA RAPIDO JET"), "lavagem")
        XCTAssertEqual(cat("ESTETICA AUTOMOTIVA BRILHO"), "lavagem", "não é cuidado pessoal")
        XCTAssertEqual(cat("IPVA 2026 DETRAN"), "carro_taxas", "custo de ter carro fica na área do carro")
        XCTAssertEqual(cat("MULTA DE TRANSITO DETRAN SP"), "carro_taxas")
        XCTAssertEqual(cat("MULTA POR ATRASO FATURA"), "tarifas")
        XCTAssertEqual(cat("ESTAPAR ESTACIONAMENTO"), "estacionamento")
        XCTAssertEqual(cat("SEM PARAR PEDAGIO"), "estacionamento")
        XCTAssertEqual(Categorias.area(de: "combustivel").chave, "carro")
        XCTAssertEqual(Categorias.area(de: "lavagem").chave, "carro")
    }

    func testTransporteEUmaAreaSeparadaDoCarro() {
        XCTAssertEqual(cat("UBER *TRIP"), "apps_transporte")
        XCTAssertEqual(cat("99APP CORRIDA"), "apps_transporte")
        XCTAssertEqual(cat("SPTRANS BILHETE UNICO"), "transporte")
        XCTAssertEqual(Categorias.area(de: "apps_transporte").chave, "transporte")
        XCTAssertEqual(Categorias.area(de: "transporte").chave, "transporte")
    }

    func testComidaEDivididaEmDeliveryLanchesRestaurantePadariaEMercado() {
        XCTAssertEqual(cat("IFOOD *PIZZARIA"), "delivery")
        XCTAssertEqual(cat("IFOOD *RESTAURANTE X"), "delivery", "a frase do iFood vale mais que a palavra restaurante")
        XCTAssertEqual(cat("UBER EATS"), "delivery", "não é corrida")
        XCTAssertEqual(cat("RAPPI*LANCHONETE"), "delivery")
        XCTAssertEqual(cat("MCDONALDS"), "lanches")
        XCTAssertEqual(cat("BURGER KING SHOPPING"), "lanches")
        XCTAssertEqual(cat("LANCHONETE DA ESQUINA"), "lanches")
        XCTAssertEqual(cat("OUTBACK STEAKHOUSE"), "restaurantes")
        XCTAssertEqual(cat("BAR E RESTAURANTE DO PORTO"), "restaurantes", "a frase inteira vence \"bar\"")
        XCTAssertEqual(cat("PADARIA PAO QUENTE"), "padaria")
        XCTAssertEqual(cat("STARBUCKS"), "padaria")
        XCTAssertEqual(cat("CARREFOUR HIPER"), "mercado")
        XCTAssertEqual(cat("EXTRA HIPER 1234"), "mercado")
        XCTAssertNotEqual(cat("HORA EXTRA SERVICOS"), "mercado", "\"extra\" sozinho não é o supermercado")
        XCTAssertNotEqual(cat("CURSO SUPERIOR"), "mercado", "\"super*\" não existe mais")
        XCTAssertEqual(cat("MERCADOLIVRE*VENDEDOR"), "compras", "Mercado Livre não é mercado")
        XCTAssertEqual(cat("MERCADOPAGO *LOJA"), "compras")
        XCTAssertEqual(cat("BAR DO ZE"), "bares")
    }

    func testEsportesEUmaAreaComLutasAcademiaEEquipamento() {
        XCTAssertEqual(cat("SMART FIT ACADEMIA"), "academia")
        XCTAssertEqual(cat("GRACIE BARRA JIU JITSU"), "lutas")
        XCTAssertEqual(cat("PAG*GRACIEBARRA 03/12 SAO PAULO"), "lutas")
        XCTAssertEqual(cat("CT MUAY THAI CENTRO"), "lutas")
        XCTAssertEqual(cat("CLUBE DE JIU JITSU ALLIANCE"), "lutas", "a frase jiu jitsu vence \"clube*\"")
        XCTAssertEqual(cat("STUDIO PILATES"), "esportes")
        XCTAssertEqual(cat("AULA DE TENIS CLUBE"), "esportes", "tênis com contexto de aula é esporte")
        XCTAssertEqual(cat("NIKE STORE"), "equipamento_esportivo")
        XCTAssertEqual(cat("CENTAURO"), "equipamento_esportivo")
        for chave in ["academia", "lutas", "esportes", "equipamento_esportivo"] {
            XCTAssertEqual(Categorias.area(de: chave).chave, "esportes")
        }
        XCTAssertEqual(Categorias.area(de: "farmacia").chave, "saude")
    }

    func testEducacaoTemFaculdadeCursosELivros() {
        XCTAssertEqual(cat("FACULDADE ANHANGUERA"), "faculdade")
        XCTAssertEqual(cat("MENSALIDADE UNI X"), "faculdade", "mensalidade + uni é faculdade")
        XCTAssertEqual(cat("MENSALIDADE COLEGIO SANTA MARIA"), "educacao")
        XCTAssertNotEqual(cat("MENSALIDADE CLUBE DO LAGO"), "educacao", "mensalidade sozinha não é escola")
        XCTAssertEqual(cat("MENSALIDADE CLUBE DO LAGO"), "lazer")
        XCTAssertEqual(cat("UDEMY ONLINE COURSES"), "cursos")
        XCTAssertEqual(cat("LIVRARIA CULTURA"), "livros")
        XCTAssertEqual(cat("AMAZON KINDLE"), "livros", "a frase vale mais que \"amazon\"")
        XCTAssertEqual(cat("XYZ", banco: "University"), "faculdade")
        XCTAssertEqual(cat("XYZ", banco: "Online Courses"), "cursos")
        for chave in ["faculdade", "cursos", "livros", "educacao"] {
            XCTAssertEqual(Categorias.area(de: chave).chave, "educacao")
        }
    }

    func testCasaSaudeEAssinaturasSaoDivididas() {
        XCTAssertEqual(cat("CONDOMINIO EDIFICIO PARQUE"), "condominio")
        XCTAssertEqual(cat("SABESP"), "agua_gas")
        XCTAssertEqual(cat("VIVO FIBRA"), "internet")
        XCTAssertEqual(cat("CLARO CELULAR POS"), "celular")
        XCTAssertEqual(cat("UNIMED BOLETO"), "plano_saude")
        XCTAssertEqual(cat("CLINICA SAO LUCAS CONSULTA"), "saude")
        XCTAssertEqual(cat("SPOTIFY"), "streaming")
        XCTAssertEqual(cat("HBO MAX"), "streaming")
        XCTAssertNotEqual(cat("POSTO MAX"), "streaming", "\"max\" sozinho não é HBO")
        XCTAssertEqual(cat("CLAUDE.AI SUBSCRIPTION"), "apps_ia")
        XCTAssertEqual(cat("APPLE.COM/BILL ICLOUD"), "apps_ia")
        XCTAssertEqual(cat("MP *IFOOD"), "delivery")
        XCTAssertEqual(cat("RENNER"), "roupas")
        XCTAssertEqual(cat("KABUM"), "eletronicos")
        XCTAssertEqual(cat("AMAZON BR"), "compras")
        XCTAssertEqual(cat("STEAM GAMES"), "jogos")
        XCTAssertEqual(cat("ESTORNO COMPRA MERCADOLIVRE"), "reembolsos", "movimentação vale mais que o nome da loja")
    }

    func testCategoriaDoBancoDetalhadaEPalavraInteira() {
        XCTAssertEqual(cat("XYZ 1", banco: "Gas stations"), "combustivel")
        XCTAssertEqual(cat("XYZ 1", banco: "Taxi and ride-hailing"), "apps_transporte")
        XCTAssertEqual(cat("XYZ 1", banco: "Food delivery"), "delivery")
        XCTAssertEqual(cat("XYZ 1", banco: "Pharmacy"), "farmacia")
        XCTAssertEqual(cat("XYZ 1", banco: "Rent"), "aluguel")
        XCTAssertNotEqual(cat("XYZ 1", banco: "Current account"), "aluguel", "\"rent\" dentro de \"current\" não é aluguel")
        // Árvore da Pluggy
        XCTAssertEqual(cat("XYZ 1", banco: "Vehicle maintenance"), "carro")
        XCTAssertEqual(cat("XYZ 1", banco: "Traffic tickets"), "carro_taxas")
        XCTAssertEqual(cat("XYZ 1", banco: "Sports practice"), "esportes")
        XCTAssertEqual(cat("XYZ 1", banco: "Gyms and fitness centers"), "academia")
        XCTAssertEqual(cat("XYZ 1", banco: "Sports goods"), "equipamento_esportivo")
        XCTAssertEqual(cat("XYZ 1", banco: "Gaming"), "jogos")
        XCTAssertEqual(cat("XYZ 1", banco: "Video streaming"), "streaming")
        XCTAssertEqual(cat("XYZ 1", banco: "Taxes on investments"), "impostos")
        XCTAssertEqual(cat("XYZ 1", banco: "Proceeds interests and dividends"), "rendimentos")
        XCTAssertEqual(cat("XYZ 1", banco: "Interests charged"), "tarifas")
        XCTAssertEqual(cat("XYZ 1", banco: "Bus tickets"), "transporte")
        XCTAssertEqual(cat("XYZ 1", banco: "Credit card payment"), "fatura")
        XCTAssertEqual(cat("XYZ 1", banco: "Fixed income"), "investimentos")
    }

    func testBancoDesempataEDaConfianca() {
        func r(_ d: String, banco: String? = nil) -> ResultadoCategoria {
            Categorizador.categorizar(descricao: d, categoriaDoBanco: banco, valorCentavos: -5_000)
        }
        // "pizza" (restaurantes) e "ifood" (delivery) têm o mesmo peso: sem banco, delivery vem antes; com banco, o banco decide.
        XCTAssertEqual(r("IFOOD PIZZA").chave, "delivery")
        XCTAssertEqual(r("IFOOD PIZZA", banco: "Eating out").chave, "restaurantes")
        XCTAssertEqual(r("IFOOD PIZZA", banco: "Food delivery").chave, "delivery")
        XCTAssertEqual(r("IFOOD PIZZA", banco: "Food delivery").confianca, 85, "o banco concordando sobe a confiança")
        XCTAssertLessThan(r("IFOOD PIZZA").confianca, r("UBER EATS").confianca, "empate baixa a confiança; frase sobe")
        XCTAssertEqual(r("XYZ").confianca, 10)
        XCTAssertEqual(r("XYZ", banco: "Eating out").confianca, 55)
        XCTAssertEqual(r("XYZ", banco: "Eating out").origem, .categoriaDoBanco)
        XCTAssertEqual(Categorizador.categorizar(descricao: "IFOOD", valorCentavos: -1, regras: [Regra(padrao: "ifood", categoriaChave: "lazer")]).confianca, 100)
    }

    func testEstabelecimentoLimpaAdquirenteParcelaECidade() {
        func loja(_ d: String, _ e: String? = nil) -> Texto.Loja { Texto.estabelecimento(d, e) }
        XCTAssertEqual(loja("PAG*GRACIEBARRA 03/12 SAO PAULO BR").chave, "graciebarra")
        XCTAssertEqual(loja("MP *IFOOD").chave, "ifood")
        XCTAssertEqual(loja("IFD*RESTAURANTE SABOR RIO DE JANEI RJ").chave, "restaurante sabor")
        XCTAssertEqual(loja("APPLE.COM/BILL ICLOUD").chave, "apple com bill", "a chave é um trecho do texto, para casar")
        XCTAssertTrue(Categorizador.casaPadrao(Texto.normalizar("APPLE.COM/BILL ICLOUD"), loja("APPLE.COM/BILL ICLOUD").chave))
        XCTAssertEqual(loja("UBER *TRIP 05/10 SAO PAULO").chave, "uber trip")
        XCTAssertEqual(loja("COMPRA NO DEBITO - PADARIA PAO QUENTE LTDA").chave, "padaria pao")
        XCTAssertEqual(loja("PAGSEGURO *ACADEMIA FORMA 123.456.***-00").chave, "academia forma")
        XCTAssertEqual(loja("SANTOS").chave, "santos", "a cidade só sai quando sobra algo antes")
        XCTAssertEqual(loja("Pix enviado").chave, "")
        XCTAssertEqual(loja("x", "Starbucks Shopping Morumbi SP").chave, "starbucks shopping")
    }

    func testTodaCategoriaTemAreaConhecidaEChaveUnica() {
        let chaves = Categorias.todas.map(\.chave)
        XCTAssertEqual(Set(chaves).count, chaves.count)
        let areas = Set(Categorias.areas.map(\.chave))
        for c in Categorias.todas { XCTAssertTrue(areas.contains(c.area), "\(c.chave) aponta para a área \(c.area)") }
        // As chaves que já estavam gravadas nos lançamentos continuam existindo.
        for antiga in ["moradia", "mercado", "contas", "transporte", "saude", "educacao", "seguros", "restaurantes",
                       "assinaturas", "lazer", "compras", "viagem", "cuidados", "pets", "presentes", "impostos",
                       "tarifas", "emprestimos", "outros", "salario", "fatura", "transferencia", "investimentos",
                       "academia", "carro", "combustivel", "estacionamento", "apps_transporte", "delivery", "padaria",
                       "streaming", "apps_ia", "roupas", "eletronicos", "bares", "farmacia", "plano_saude", "aluguel",
                       "condominio", "luz", "agua_gas", "internet", "celular", "freelas", "rendimentos", "reembolsos",
                       "outras_receitas"] {
            XCTAssertEqual(Categorias.info(antiga).chave, antiga)
        }
        for (palavra, _) in Categorizador.palavras.map({ ($0.0, $0.1) }) {
            XCTAssertEqual(Categorias.info(palavra).chave, palavra, "lista de palavras usa categoria que não existe")
        }
        for (chave, _) in Categorizador.compostos {
            XCTAssertEqual(Categorias.info(chave).chave, chave)
        }
        for (_, chave) in Categorizador.categoriaDoBanco {
            XCTAssertEqual(Categorias.info(chave).chave, chave)
        }
        // Cada termo do dicionário cai na própria categoria quando aparece sozinho.
        for (chave, termos) in Categorizador.palavras {
            for termo in termos {
                let texto = termo.hasSuffix("*") ? String(termo.dropLast()) + "x" : termo
                XCTAssertEqual(Categorizador.categorizar(descricao: texto, valorCentavos: -1_000).chave, chave,
                               "\"\(termo)\" devia cair em \(chave)")
            }
        }
    }

    func testPorAreaSomaAsCategorias() {
        let areas = Analise.porArea([
            GastoCategoria(chave: "combustivel", centavos: 60_000, quantidade: 3, percentual: 0.6),
            GastoCategoria(chave: "lavagem", centavos: 20_000, quantidade: 5, percentual: 0.2),
            GastoCategoria(chave: "delivery", centavos: 15_000, quantidade: 4, percentual: 0.15),
            GastoCategoria(chave: "apps_transporte", centavos: 5_000, quantidade: 2, percentual: 0.05),
        ])
        XCTAssertEqual(areas.map(\.chave), ["carro", "alimentacao", "transporte"], "Uber é Transporte, não Carro")
        XCTAssertEqual(areas[0].centavos, 80_000)
        XCTAssertEqual(areas[0].quantidade, 8)
        XCTAssertEqual(areas[0].percentual, 0.8, accuracy: 0.0001)
        XCTAssertEqual(areas[0].categorias.map(\.chave), ["combustivel", "lavagem"])
    }

    // MARK: Recategorizar

    func testRefinarTrocaAmplaPorDetalhadaSemTocarNoQueEManual() throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        func novo(_ id: String, _ desc: String, _ chave: String, manual: Bool = false, interno: Bool = false) -> Lancamento {
            let l = Lancamento(externalID: id, contaID: "cc", data: data(2026, 10, 5), descricao: desc, valorCentavos: -5_000, origem: .openFinance)
            l.categoriaChave = chave
            l.categoriaManual = manual
            l.interno = interno
            ctx.insert(l)
            return l
        }
        let posto = novo("1", "POSTO SHELL", "transporte")
        let uber = novo("2", "UBER *TRIP", "transporte")
        let ifood = novo("3", "IFOOD *PIZZARIA", "restaurantes")
        let manual = novo("4", "POSTO IPIRANGA", "transporte", manual: true)
        let semPista = novo("5", "XYZ COMERCIO", "transporte")
        let outro = novo("6", "FAXINA MARIA", "outros")
        let livre = novo("7", "MERCADOLIVRE*LOJA", "mercado")
        let trocado = novo("8", "POSTO SHELL", "lazer")
        ctx.insert(Regra(padrao: "ifood", categoriaChave: "restaurantes"))
        try ctx.save()

        let mudou = try Recategorizador.refinar(ctx)
        XCTAssertEqual(mudou, 4)
        XCTAssertEqual(posto.categoriaChave, "combustivel")
        XCTAssertEqual(uber.categoriaChave, "apps_transporte")
        XCTAssertEqual(ifood.categoriaChave, "restaurantes", "regra do usuário continua mandando")
        XCTAssertEqual(manual.categoriaChave, "transporte", "o que foi escolhido à mão não muda")
        XCTAssertEqual(semPista.categoriaChave, "transporte")
        XCTAssertEqual(outro.categoriaChave, "moradia")
        XCTAssertEqual(livre.categoriaChave, "compras")
        XCTAssertEqual(trocado.categoriaChave, "lazer", "só refina dentro da mesma família")
        XCTAssertEqual(try Recategorizador.refinar(ctx), 0, "rodar de novo não muda nada")
    }

    func testRefinarVersao3MoveParaEsportesEducacaoEAssinaturaPorRecorrencia() throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        var n = 0
        func novo(_ desc: String, _ chave: String, _ d: Date = data(2026, 10, 5), valor: Int = -5_000, manual: Bool = false) -> Lancamento {
            n += 1
            let l = Lancamento(externalID: "\(n)", contaID: "cc", data: d, descricao: desc, valorCentavos: valor, origem: .openFinance)
            l.categoriaChave = chave
            l.categoriaManual = manual
            ctx.insert(l)
            return l
        }
        let jiu = novo("GRACIE BARRA JIU JITSU", "academia")
        let nike = novo("NIKE STORE", "roupas")
        let steam = novo("STEAM GAMES", "lazer")
        let mc = novo("MCDONALDS", "restaurantes")
        let lava = novo("LAVA RAPIDO JET", "carro")
        let ipva = novo("IPVA 2026 DETRAN", "carro")
        let udemy = novo("UDEMY", "educacao")
        let manual = novo("CENTAURO", "roupas", manual: true)
        // Loja desconhecida cobrando R$ 29,90 todo mês: assinatura. Outra com valores diferentes: continua "Outros".
        for m in 7...10 { _ = novo("XPTO CLUB SERVICOS", "outros", data(2026, m, 3), valor: -2_990) }
        let variavel = (7...10).map { novo("ZETA COMERCIO", "outros", data(2026, $0, 9), valor: -1_000 * $0) }
        let umaVez = novo("QUALQUER COISA", "outros")
        try ctx.save()

        let mudou = try Recategorizador.refinar(ctx)
        XCTAssertEqual(jiu.categoriaChave, "lutas")
        XCTAssertEqual(nike.categoriaChave, "equipamento_esportivo")
        XCTAssertEqual(steam.categoriaChave, "jogos")
        XCTAssertEqual(mc.categoriaChave, "lanches")
        XCTAssertEqual(lava.categoriaChave, "lavagem")
        XCTAssertEqual(ipva.categoriaChave, "carro_taxas")
        XCTAssertEqual(udemy.categoriaChave, "cursos")
        XCTAssertEqual(manual.categoriaChave, "roupas", "escolha à mão fica")
        let xpto = try ctx.fetch(FetchDescriptor<Lancamento>()).filter { $0.descricao.hasPrefix("XPTO") }
        XCTAssertEqual(xpto.count, 4)
        XCTAssertTrue(xpto.allSatisfy { $0.categoriaChave == "assinaturas" }, "mesmo valor todo mês vira assinatura")
        XCTAssertTrue(variavel.allSatisfy { $0.categoriaChave == "outros" }, "valor diferente a cada mês não é assinatura")
        XCTAssertEqual(umaVez.categoriaChave, "outros")
        XCTAssertEqual(mudou, 7 + 4)
        XCTAssertEqual(try Recategorizador.refinar(ctx), 0)
        XCTAssertEqual(Recategorizador.versao, 3)
    }

    // MARK: Conferência

    func testConferenciaAgrupaPorLojaEPoeOutrosEDuvidasPrimeiro() {
        let conta = Conta(externalID: "cc", nome: "Conta", tipo: .corrente, instituicao: "Banco")
        var n = 0
        func gasto(_ d: Date, _ desc: String, _ centavos: Int, _ chave: String) -> Lancamento {
            n += 1
            let l = Lancamento(externalID: "l\(n)", contaID: "cc", data: d, descricao: desc, valorCentavos: -centavos, origem: .openFinance)
            l.categoriaChave = chave
            return l
        }
        let hoje = data(2026, 10, 13)
        var ls: [Lancamento] = []
        for m in 8...10 { ls.append(gasto(data(2026, m, 5), "POSTO SHELL", 20_000, "combustivel")) }
        for m in 9...10 { ls.append(gasto(data(2026, m, 8), "IFOOD PIZZA", 5_000, "delivery")) }
        ls.append(gasto(data(2026, 10, 2), "XPTO CLUB", 9_900, "outros"))
        ls.append(gasto(data(2026, 10, 3), "ZETA COMERCIO", 100, "outros"))
        ls.append(gasto(data(2026, 10, 4), "GRACIE BARRA", 30_000, "lutas"))
        ls.append(gasto(data(2024, 1, 4), "ANTIGO DEMAIS", 30_000, "outros"))
        ls.append(gasto(data(2026, 10, 6), "SALARIO", -1, "salario")) // entrada: não é gasto
        let regra = Regra(padrao: "gracie barra", categoriaChave: "lutas")

        let lojas = Analise.conferenciaCategorias(lancamentos: ls, contas: [conta], regras: [regra], hoje: hoje)
        XCTAssertEqual(lojas.map(\.chave), ["xpto club", "zeta comercio", "ifood pizza", "posto shell", "gracie barra"])
        XCTAssertEqual(lojas[0].confianca, 10)
        XCTAssertEqual(lojas[2].categoriaChave, "delivery")
        XCTAssertEqual(lojas[2].vezes, 2)
        XCTAssertLessThan(lojas[2].confianca, lojas[3].confianca, "ifood + pizza é disputa; posto shell não")
        XCTAssertEqual(lojas[3].totalCentavos, 60_000)
        XCTAssertEqual(lojas[3].externalIDs.count, 3)
        XCTAssertEqual(lojas[4].confianca, 100, "regra sua")
        XCTAssertEqual(Analise.conferenciaCategorias(lancamentos: LancamentoLeve.copiar(ls, hoje: hoje), contas: [conta], regras: [regra], hoje: hoje), lojas)
    }

    func testCopiaLeveComTrezeMesesContinuaRapida() throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        let hoje = data(2026, 10, 13)
        try DadosDemo.popular(ctx, hoje: hoje)
        let ls = try ctx.fetch(FetchDescriptor<Lancamento>())
        let inicio = Date()
        let leves = LancamentoLeve.copiar(ls, hoje: hoje)
        let ms = Date().timeIntervalSince(inicio) * 1000
        print("LancamentoLeve.copiar: \(ls.count) lançamentos em \(Int(ms)) ms")
        XCTAssertEqual(leves.count, ls.count)
        XCTAssertLessThan(ms, 2_000)
    }

    // MARK: Destaques

    func testDestaquesComparamComAMesmaAlturaDosMesesAnteriores() {
        let conta = Conta(externalID: "cc", nome: "Conta", tipo: .corrente, instituicao: "Banco")
        var n = 0
        func gasto(_ d: Date, _ desc: String, _ centavos: Int, _ chave: String) -> Lancamento {
            n += 1
            let l = Lancamento(externalID: "l\(n)", contaID: "cc", data: d, descricao: desc, valorCentavos: -centavos, origem: .openFinance)
            l.categoriaChave = chave
            return l
        }
        var ls: [Lancamento] = []
        // Três meses anteriores: R$ 200 de gasolina até o dia 10 e R$ 300 de mercado depois do dia 20.
        for mes in [7, 8, 9] {
            ls.append(gasto(data(2026, mes, 5), "POSTO SHELL", 20_000, "combustivel"))
            ls.append(gasto(data(2026, mes, 8), "IFOOD", 10_000, "delivery"))
            ls.append(gasto(data(2026, mes, 25), "CARREFOUR", 30_000, "mercado"))
        }
        // Outubro até o dia 13: gasolina dobrou, delivery sumiu, cinco cafés pequenos e uma compra grande.
        ls.append(gasto(data(2026, 10, 4), "POSTO SHELL", 40_000, "combustivel"))
        for d in 1...5 { ls.append(gasto(data(2026, 10, d), "CAFE DO CENTRO", 1_500, "padaria")) }
        ls.append(gasto(data(2026, 10, 9), "KABUM", 25_000, "eletronicos"))

        let hoje = data(2026, 10, 13)
        let d = Analise.destaquesDoMes(lancamentos: ls, contas: [conta], hoje: hoje)
        func item(_ id: String) -> Destaque? { d.first { $0.id == id } }

        // 400 + 75 + 250 = 725 agora; em setembro até o dia 13 foram 300.
        XCTAssertEqual(item("ritmo")?.tom, .atencao)
        XCTAssertTrue(item("ritmo")?.titulo.contains("425") == true, item("ritmo")?.titulo ?? "")
        XCTAssertTrue(item("ritmo")?.titulo.contains("setembro") == true)
        XCTAssertEqual(item("maior-categoria")?.categoriaChave, "combustivel")
        XCTAssertNotNil(item("acima-combustivel"))
        XCTAssertTrue(item("acima-combustivel")?.titulo.contains("200") == true)
        XCTAssertNotNil(item("abaixo-delivery"))
        XCTAssertNil(item("abaixo-mercado"), "mercado só acontece depois do dia 20: não é economia")
        XCTAssertTrue(item("lugar")?.titulo.contains("5 vezes") == true)
        XCTAssertTrue(item("pequenas")?.titulo.contains("5 compras") == true)
        XCTAssertEqual(item("maior-compra")?.categoriaChave, "combustivel")
        // Média mensal 600; já gastou 725.
        XCTAssertEqual(item("por-dia")?.tom, .atencao)
        XCTAssertTrue(Analise.destaquesDoMes(lancamentos: [Lancamento](), contas: [conta], hoje: hoje).isEmpty)
    }

    // MARK: CDI

    private let respostaBCB = Data(#"[{"data":"01/09/2025","valor":"1.22"},{"data":"01/10/2025","valor":"1.28"},{"data":"01/11/2025","valor":"1.05"},{"data":"01/12/2025","valor":"1.22"},{"data":"01/01/2026","valor":"1.16"},{"data":"01/02/2026","valor":"1.00"},{"data":"01/03/2026","valor":"1.21"},{"data":"01/04/2026","valor":"1.09"},{"data":"01/05/2026","valor":"1.07"},{"data":"01/06/2026","valor":"1.12"},{"data":"01/07/2026","valor":"1.22"},{"data":"01/08/2026","valor":"1.09"},{"data":"01/09/2026","valor":"1.08"},{"data":"01/10/2026","valor":"0.36"}]"#.utf8)

    func testLeOCDIDoBancoCentral() throws {
        let t = try CDI.ler(respostaBCB, agora: data(2026, 10, 13))
        XCTAssertEqual(t.taxa(data(2026, 9, 15)) ?? 0, 0.0108, accuracy: 0.000001)
        XCTAssertNil(t.taxa(data(2024, 1, 1)))
        // Doze meses fechados até setembro: de outubro/2025 a setembro/2026.
        let doze = try XCTUnwrap(t.acumulado(meses: 12, ate: data(2026, 9, 1)))
        XCTAssertEqual(doze, 0.1445, accuracy: 0.001)
        XCTAssertNil(t.acumulado(meses: 24, ate: data(2026, 9, 1)), "sem todos os meses, não inventa")
        XCTAssertThrowsError(try CDI.ler(Data("[]".utf8)))
        XCTAssertThrowsError(try CDI.ler(Data("erro".utf8)))
    }

    func testCDIUsaOGuardadoQuandoARedeFalha() async throws {
        let nome = "prumo.teste.cdi.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: nome))
        defer { defaults.removePersistentDomain(forName: nome) }
        let corpo = respostaBCB
        let ok = TransporteFalso { _, _ in (200, corpo, [:]) }
        let agora = data(2026, 10, 13)
        let primeira = await CDI.atualizar(defaults: defaults, transporte: ok, agora: agora)
        XCTAssertNotNil(primeira?.taxa(data(2026, 9, 1)))
        XCTAssertEqual(ok.registro.count, 1)
        // Recente: nem consulta a rede.
        _ = await CDI.atualizar(defaults: defaults, transporte: ok, agora: agora.addingTimeInterval(3600))
        XCTAssertEqual(ok.registro.count, 1)
        // Velho e sem rede: fica com o que tinha.
        let fora = TransporteFalso { _, _ in (503, Data(), [:]) }
        let depois = await CDI.atualizar(defaults: defaults, transporte: fora, agora: agora.addingTimeInterval(48 * 3600))
        XCTAssertEqual(depois?.porMes, primeira?.porMes)
        XCTAssertEqual(fora.registro.count, 1)
    }

    // MARK: Fechamento

    func testFechamentoDizOQueBateuOCDI() throws {
        let cdi = try CDI.ler(respostaBCB, agora: data(2026, 10, 13))
        func inv(_ id: String, _ nome: String, _ saldo: Int, mes: Double?, doze: Double? = nil, subtipo: String? = nil) -> Investimento {
            let i = Investimento(externalID: id, nome: nome, classe: .rendaFixa, saldoCentavos: saldo)
            i.rentabilidadeMes = mes
            i.rentabilidade12m = doze
            i.subtipo = subtipo
            return i
        }
        let invs = [
            inv("cdb", "CDB 110% CDI", 1_000_000, mes: 0.0119, doze: 0.1590),
            inv("fundo", "Fundo Multimercado", 1_000_000, mes: 0.0070, doze: 0.10),
            inv("lci", "LCI 95% CDI", 1_000_000, mes: 0.0100, subtipo: "LCI"),
            inv("acao", "WEG ON", 500_000, mes: -0.02),
            inv("btc", "Bitcoin", 300_000, mes: nil),
            inv("zerado", "Antigo", 0, mes: 0.01),
        ]
        let f = Analise.fechamentoInvestimentos(invs, cdi: cdi, hoje: data(2026, 10, 13))
        XCTAssertEqual(f.mes, data(2026, 9, 1, hora: 0))
        XCTAssertEqual(f.nomeDoMes, "setembro")
        XCTAssertEqual(f.cdiMes ?? 0, 0.0108, accuracy: 0.000001)
        XCTAssertEqual(f.total, 5)
        XCTAssertEqual(f.cobertos, 4)
        XCTAssertEqual(f.bateram.map(\.id), ["cdb", "lci"], "LCI é isenta: 93% do CDI já vale a pena")
        XCTAssertEqual(f.abaixo.map(\.id), ["fundo"])
        XCTAssertEqual(f.perderam.map(\.id), ["acao"])
        XCTAssertEqual(f.semDados.map(\.id), ["btc"])
        XCTAssertEqual(f.itens.first?.id, "cdb")
        XCTAssertEqual(f.itens.last?.id, "btc")
        let cdb = try XCTUnwrap(f.itens.first)
        XCTAssertEqual(cdb.percentualDoCDI ?? 0, 0.0119 / 0.0108, accuracy: 0.0001)
        XCTAssertEqual(cdb.rendeuCentavos ?? 0, 11_760, accuracy: 2)
        XCTAssertEqual(cdb.percentualDoCDI12m ?? 0, 0.1590 / 0.1445, accuracy: 0.01)
        XCTAssertNotNil(f.percentualDoCDI)
        XCTAssertTrue(f.frase.contains("setembro"))
        XCTAssertTrue(f.frase.contains("do CDI"))

        // Sem o CDI, ainda fecha o mês, só sem a comparação.
        let sem = Analise.fechamentoInvestimentos(invs, cdi: nil, hoje: data(2026, 10, 13))
        XCTAssertNil(sem.percentualDoCDI)
        XCTAssertEqual(sem.perderam.map(\.id), ["acao"])
        XCTAssertFalse(sem.frase.contains("CDI"))

        // Aviso na primeira semana do mês.
        let aviso = Analise.insights(lancamentos: [Lancamento](), contas: [], investimentos: [], orcamentos: [], recorrentes: [],
                                     vencimentos: [], conexoes: [], ultimaAtualizacao: nil,
                                     fechamento: Analise.fechamentoInvestimentos(invs, cdi: cdi, hoje: data(2026, 10, 3)),
                                     hoje: data(2026, 10, 3))
        XCTAssertEqual(aviso.first?.id, "fechamento-2026-09")
        let tarde = Analise.insights(lancamentos: [Lancamento](), contas: [], investimentos: [], orcamentos: [], recorrentes: [],
                                     vencimentos: [], conexoes: [], ultimaAtualizacao: nil, fechamento: f, hoje: data(2026, 10, 13))
        XCTAssertTrue(tarde.isEmpty)
    }

    // MARK: Cópia leve

    func testCopiaLeveDaOMesmoResultadoQueOModelo() throws {
        container = try EsquemaPrumo.container(emMemoria: true)
        let ctx = container.mainContext
        let hoje = data(2026, 10, 13)
        try DadosDemo.popular(ctx, hoje: hoje)
        let ls = try ctx.fetch(FetchDescriptor<Lancamento>())
        let cs = try ctx.fetch(FetchDescriptor<Conta>())
        let fixos = try ctx.fetch(FetchDescriptor<Fixo>())
        let marcas = try ctx.fetch(FetchDescriptor<MarcaFixo>())
        let leves = LancamentoLeve.copiar(ls, hoje: hoje)

        let a = Analise.resumoDoMes(hoje, lancamentos: ls, contas: cs, hoje: hoje)
        let b = Analise.resumoDoMes(hoje, lancamentos: leves, contas: cs, hoje: hoje)
        XCTAssertEqual(a.despesasCentavos, b.despesasCentavos)
        XCTAssertEqual(a.porCategoria, b.porCategoria)
        XCTAssertEqual(Analise.previsaoDoMes(lancamentos: ls, contas: cs, hoje: hoje),
                       Analise.previsaoDoMes(lancamentos: leves, contas: cs, hoje: hoje))
        XCTAssertEqual(Analise.recorrentes(lancamentos: ls, contas: cs, hoje: hoje),
                       Analise.recorrentes(lancamentos: leves, contas: cs, hoje: hoje))
        XCTAssertEqual(Analise.destaquesDoMes(lancamentos: ls, contas: cs, hoje: hoje),
                       Analise.destaquesDoMes(lancamentos: leves, contas: cs, hoje: hoje))
        XCTAssertEqual(Fixos.situacao(fixos: fixos, marcas: marcas, lancamentos: ls, mes: hoje),
                       Fixos.situacao(fixos: fixos, marcas: marcas, lancamentos: leves, mes: hoje))
    }
}
