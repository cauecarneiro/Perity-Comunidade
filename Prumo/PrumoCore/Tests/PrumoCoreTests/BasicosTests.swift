import XCTest
@testable import PrumoCore

final class DinheiroTests: XCTestCase {
    func testLeituraDeFormatos() {
        XCTAssertEqual(Dinheiro.ler("R$ 45,90"), 4590)
        XCTAssertEqual(Dinheiro.ler("45.90"), 4590)
        XCTAssertEqual(Dinheiro.ler("1.234,56"), 123_456)
        XCTAssertEqual(Dinheiro.ler("1,234.56"), 123_456)
        XCTAssertEqual(Dinheiro.ler("BRL 12.5"), 1250)
        XCTAssertEqual(Dinheiro.ler("R$ 1.234"), 123_400)
        XCTAssertEqual(Dinheiro.ler("1234"), 123_400)
        XCTAssertEqual(Dinheiro.ler("0,99"), 99)
        XCTAssertNil(Dinheiro.ler("sem valor"))
    }

    func testCentavosSemErroDePontoFlutuante() {
        XCTAssertEqual(Dinheiro.centavos(0.1 + 0.2), 30)
        XCTAssertEqual(Dinheiro.centavos(2540.37), 254_037)
        XCTAssertEqual(Dinheiro.centavos(-54.9), -5490)
    }

    func testFormatacao() {
        let s = Dinheiro.formatar(123_456)
        XCTAssertTrue(s.contains("1.234,56"), s)
        XCTAssertTrue(Dinheiro.formatarCompacto(320_000).contains("3,2 mil"), Dinheiro.formatarCompacto(320_000))
        XCTAssertTrue(Dinheiro.formatarCompacto(150_000_000).contains("mi"))
    }
}

final class TextoEDatasTests: XCTestCase {
    func testNormalizar() {
        XCTAssertEqual(Texto.normalizar("PÃO de Açúcar*  Loja #12"), "pao de acucar loja 12")
    }

    func testNomeExibicao() {
        XCTAssertEqual(Texto.nomeExibicao("COMPRA NO DEBITO - CARREFOUR HIPER"), "Carrefour Hiper")
        XCTAssertEqual(Texto.nomeExibicao("Padaria do Zé"), "Padaria do Zé")
        XCTAssertEqual(Texto.nomeExibicao("PAO DE ACUCAR"), "Pao de Acucar")
        XCTAssertEqual(Texto.nomeExibicao("CAFE DO CENTRO LTDA"), "Cafe do Centro Ltda")
    }

    func testPrimeiraMaiuscula() {
        XCTAssertEqual(Texto.primeiraMaiuscula("sábado, 10 de outubro"), "Sábado, 10 de outubro")
        XCTAssertEqual(Texto.primeiraMaiuscula(""), "")
    }

    func testOcultarDinheiro() {
        XCTAssertEqual(Texto.ocultarDinheiro("Fatura vence em 3 dias: R$ 2.776,96."), "Fatura vence em 3 dias: R$ ••••.")
        XCTAssertEqual(Texto.ocultarDinheiro("média R$ 9,7 mil e −R$ 120,00"), "média R$ •••• e R$ ••••")
        XCTAssertEqual(Texto.ocultarDinheiro("Sem valores aqui, 92% do orçamento"), "Sem valores aqui, 92% do orçamento")
    }

    /// Meia-noite UTC não pode virar "ontem" no fuso de Brasília.
    func testDiaCivilPreservaODia() {
        let utc = PluggyJSON.data(de: "2026-10-05T00:00:00.000Z")!
        let dia = Datas.diaCivil(deUTC: utc)
        let comp = Datas.calendario.dateComponents([.year, .month, .day, .hour], from: dia)
        XCTAssertEqual(comp.day, 5)
        XCTAssertEqual(comp.month, 10)
        XCTAssertEqual(comp.hour, 12)
    }

    func testDatasDaPluggy() {
        XCTAssertNotNil(PluggyJSON.data(de: "2026-10-05T00:00:00.000Z"))
        XCTAssertNotNil(PluggyJSON.data(de: "2026-10-05T00:00:00Z"))
        XCTAssertNotNil(PluggyJSON.data(de: "2026-10-05"))
        XCTAssertNil(PluggyJSON.data(de: "ontem"))
    }
}

final class CategorizadorTests: XCTestCase {
    private func cat(_ d: String, valor: Int = -5000, cartao: Bool = false, regras: [Regra] = []) -> ResultadoCategoria {
        Categorizador.categorizar(descricao: d, valorCentavos: valor, ehCartao: cartao, regras: regras)
    }

    func testPalavrasConhecidas() {
        XCTAssertEqual(cat("IFOOD *RESTAURANTE").chave, "delivery")
        XCTAssertEqual(cat("NETFLIX.COM").chave, "streaming")
        XCTAssertEqual(cat("UBER *TRIP").chave, "apps_transporte")
        XCTAssertEqual(cat("CARREFOUR HIPER").chave, "mercado")
        XCTAssertEqual(cat("DROGASIL 1234").chave, "farmacia")
        XCTAssertEqual(cat("ALUGUEL IMOBILIARIA CENTRAL").chave, "aluguel")
        XCTAssertEqual(cat("ENEL DISTRIBUICAO ENERGIA").chave, "luz")
        XCTAssertEqual(cat("SALARIO EMPRESA XYZ", valor: 980_000).chave, "salario")
    }

    func testNaoCasaPedacoDePalavra() {
        // "extra" dentro de "extraordinario" não é o supermercado.
        XCTAssertNotEqual(cat("PAGAMENTO EXTRAORDINARIO").chave, "mercado")
        // "bar" não casa dentro de "barbearia" (que é cuidados).
        XCTAssertEqual(cat("BARBEARIA DO JOAO").chave, "cuidados")
    }

    func testInternosSaoNeutros() {
        // Pagamento de fatura só vira "interno" quando casa com o par no cartão (Conciliador.parearFaturas).
        XCTAssertEqual(cat("PAGAMENTO DE FATURA CARTAO AZUL").chave, "fatura")
        XCTAssertFalse(cat("PAGAMENTO DE FATURA CARTAO AZUL").interno)
        XCTAssertTrue(cat("APLICACAO CDB").interno)
        XCTAssertEqual(cat("RESGATE CDB", valor: 100_000).chave, "investimentos")
        XCTAssertFalse(cat("IFOOD *RESTAURANTE").interno)
    }

    func testRegraDoUsuarioVenceTudo() {
        let regra = Regra(padrao: "ifood", categoriaChave: "lazer")
        XCTAssertEqual(cat("IFOOD *RESTAURANTE", regras: [regra]).chave, "lazer")
        XCTAssertEqual(cat("IFOOD *RESTAURANTE", regras: [regra]).origem, .regraDoUsuario)
    }

    func testRegraCasaPelaChaveDeLojaMesmoComNumeroNoMeio() {
        // "Barbearia 123 Centro" vira a chave "barbearia centro", que não é um trecho do texto; a regra tem de casar mesmo assim.
        let descricao = "BARBEARIA 123 CENTRO"
        let padrao = Categorizador.padraoParaRegra(descricao: descricao)
        XCTAssertFalse(padrao.isEmpty)
        let regra = Regra(padrao: padrao, categoriaChave: "lazer")
        XCTAssertEqual(cat(descricao, regras: [regra]).chave, "lazer")
        XCTAssertEqual(cat("BARBEARIA 456 CENTRO", regras: [regra]).chave, "lazer", "outro número, mesma loja")
    }

    func testCategoriaDoBancoComoReserva() {
        let r = Categorizador.categorizar(descricao: "XYZ COMERCIO 77", categoriaDoBanco: "Eating out", valorCentavos: -4000)
        XCTAssertEqual(r.chave, "restaurantes")
        XCTAssertEqual(r.origem, .categoriaDoBanco)
    }

    func testPadraoParaRegra() {
        XCTAssertEqual(Categorizador.padraoParaRegra(descricao: "COMPRA NO DEBITO - PADARIA PAO QUENTE LTDA"), "padaria pao")
        XCTAssertEqual(Categorizador.padraoParaRegra(descricao: "x", estabelecimento: "Padaria Pão Quente"), "padaria pao")
        // Nada específico → sem regra (evita transformar todo Pix ou toda compra no débito em uma categoria).
        XCTAssertEqual(Categorizador.padraoParaRegra(descricao: "Pix enviado"), "")
        XCTAssertEqual(Categorizador.padraoParaRegra(descricao: "COMPRA NO DEBITO"), "")
        XCTAssertEqual(Categorizador.padraoParaRegra(descricao: "Transferência enviada pelo Pix - MARIA SILVA"), "maria silva")
    }

    func testRegraCasaPalavraInteira() {
        let regra = Regra(padrao: "bar", categoriaChave: "lazer")
        XCTAssertEqual(Categorizador.categorizar(descricao: "BARBEARIA DO JOAO", valorCentavos: -3000, regras: [regra]).chave, "cuidados")
        XCTAssertEqual(Categorizador.categorizar(descricao: "BAR DO ZE", valorCentavos: -3000, regras: [regra]).chave, "lazer")
        XCTAssertTrue(Categorizador.casaPadrao("pao de acucar loja 3", "pao de acucar"))
        XCTAssertFalse(Categorizador.casaPadrao("carrefour barra", "bar"))
    }

    func testFaturaDeContaDeConsumoNaoEhFaturaDeCartao() {
        XCTAssertEqual(Categorizador.categorizar(descricao: "PAGAMENTO FATURA VIVO", valorCentavos: -9990).chave, "celular")
        let nubank = Categorizador.categorizar(descricao: "Pagamento da fatura", valorCentavos: -300_000)
        XCTAssertEqual(nubank.chave, "fatura")
        XCTAssertFalse(nubank.interno, "só vira interno quando casa com o pagamento recebido no cartão")
    }

    func testPalavrasPerigosasNaoCasam() {
        XCTAssertNotEqual(Categorizador.categorizar(descricao: "APLICATIVO DE ENTREGA", valorCentavos: -2000).chave, "investimentos")
        XCTAssertEqual(Categorizador.categorizar(descricao: "TESOURO NACIONAL DARF", valorCentavos: -50_000).chave, "impostos")
        XCTAssertNotEqual(Categorizador.categorizar(descricao: "PADARIA DAS FLORES", valorCentavos: -1500).chave, "impostos")
        XCTAssertNotEqual(Categorizador.categorizar(descricao: "AEROPORTO GRU", valorCentavos: -4000).chave, "impostos")
    }
}
