import Foundation

public enum GrupoCategoria: String, Sendable {
    case essencial, estiloDeVida, financeiro, receita, neutro

    public var nome: String {
        switch self {
        case .essencial: "Essenciais"
        case .estiloDeVida: "Estilo de vida"
        case .financeiro: "Financeiro"
        case .receita: "Receitas"
        case .neutro: "Movimentações"
        }
    }
}

/// Uma área junta categorias parecidas ("Carro" = gasolina, manutenção, limpeza, estacionamento…).
/// É o macro; as categorias são o micro.
public struct AreaCategoria: Identifiable, Hashable, Sendable {
    public let chave: String
    public let nome: String
    public let icone: String
    public var id: String { chave }
}

public struct CategoriaInfo: Identifiable, Hashable, Sendable {
    public let chave: String
    public let nome: String
    public let icone: String
    public let corHex: String
    public let grupo: GrupoCategoria
    /// Chave da área a que pertence (ver `Categorias.areas`).
    public let area: String
    public var id: String { chave }

    public init(chave: String, nome: String, icone: String, corHex: String, grupo: GrupoCategoria, area: String) {
        self.chave = chave
        self.nome = nome
        self.icone = icone
        self.corHex = corHex
        self.grupo = grupo
        self.area = area
    }

    public var ehReceita: Bool { grupo == .receita }
    public var ehDespesa: Bool { grupo == .essencial || grupo == .estiloDeVida || grupo == .financeiro }
}

public enum Categorias {
    public static let areas: [AreaCategoria] = [
        .init(chave: "casa", nome: "Casa", icone: "house.fill"),
        .init(chave: "alimentacao", nome: "Alimentação", icone: "fork.knife"),
        .init(chave: "carro", nome: "Carro", icone: "car.fill"),
        .init(chave: "transporte", nome: "Transporte", icone: "tram.fill"),
        .init(chave: "saude", nome: "Saúde", icone: "cross.case.fill"),
        .init(chave: "esportes", nome: "Esportes", icone: "figure.run"),
        .init(chave: "assinaturas", nome: "Assinaturas", icone: "arrow.triangle.2.circlepath"),
        .init(chave: "compras", nome: "Compras", icone: "bag.fill"),
        .init(chave: "lazer", nome: "Lazer e viagem", icone: "theatermasks.fill"),
        .init(chave: "educacao", nome: "Educação", icone: "graduationcap.fill"),
        .init(chave: "financeiro", nome: "Taxas, impostos e seguros", icone: "percent"),
        .init(chave: "outros", nome: "Outros", icone: "ellipsis.circle.fill"),
        .init(chave: "receitas", nome: "Receitas", icone: "arrow.down.circle.fill"),
        .init(chave: "movimentacoes", nome: "Movimentações", icone: "arrow.left.arrow.right"),
    ]

    /// As categorias são bem divididas de propósito: a pergunta é "onde exatamente o dinheiro foi".
    /// Nenhuma chave é removida: as amplas (moradia, contas, transporte, saude, restaurantes, assinaturas,
    /// compras, lazer, carro, educacao, academia) continuam valendo, como o "resto" ou um item da sua área.
    public static let todas: [CategoriaInfo] = [
        // Casa
        .init(chave: "aluguel", nome: "Aluguel", icone: "key.fill", corHex: "3B82F6", grupo: .essencial, area: "casa"),
        .init(chave: "condominio", nome: "Condomínio", icone: "building.2.fill", corHex: "60A5FA", grupo: .essencial, area: "casa"),
        .init(chave: "luz", nome: "Luz", icone: "bolt.fill", corHex: "FACC15", grupo: .essencial, area: "casa"),
        .init(chave: "agua_gas", nome: "Água e gás", icone: "drop.fill", corHex: "38BDF8", grupo: .essencial, area: "casa"),
        .init(chave: "internet", nome: "Internet e TV", icone: "wifi", corHex: "818CF8", grupo: .essencial, area: "casa"),
        .init(chave: "celular", nome: "Celular", icone: "iphone", corHex: "A3E635", grupo: .essencial, area: "casa"),
        .init(chave: "moradia", nome: "Casa e reparos", icone: "house.fill", corHex: "2563EB", grupo: .essencial, area: "casa"),
        .init(chave: "contas", nome: "Outras contas", icone: "doc.text.fill", corHex: "93C5FD", grupo: .essencial, area: "casa"),
        // Alimentação
        .init(chave: "mercado", nome: "Mercado", icone: "cart.fill", corHex: "17B26A", grupo: .essencial, area: "alimentacao"),
        .init(chave: "delivery", nome: "Delivery", icone: "bag.fill", corHex: "F97316", grupo: .estiloDeVida, area: "alimentacao"),
        .init(chave: "restaurantes", nome: "Restaurantes", icone: "fork.knife", corHex: "FF7A45", grupo: .estiloDeVida, area: "alimentacao"),
        .init(chave: "lanches", nome: "Lanches e fast food", icone: "takeoutbag.and.cup.and.straw.fill", corHex: "FB923C", grupo: .estiloDeVida, area: "alimentacao"),
        .init(chave: "padaria", nome: "Padaria e café", icone: "cup.and.saucer.fill", corHex: "D6A46A", grupo: .estiloDeVida, area: "alimentacao"),
        // Carro
        .init(chave: "combustivel", nome: "Gasolina", icone: "fuelpump.fill", corHex: "12B5CB", grupo: .essencial, area: "carro"),
        .init(chave: "carro", nome: "Manutenção e peças", icone: "wrench.and.screwdriver.fill", corHex: "0EA5E9", grupo: .essencial, area: "carro"),
        .init(chave: "lavagem", nome: "Limpeza e estética", icone: "bubbles.and.sparkles.fill", corHex: "7DD3FC", grupo: .estiloDeVida, area: "carro"),
        .init(chave: "estacionamento", nome: "Estacionamento e pedágio", icone: "parkingsign", corHex: "67E8F9", grupo: .essencial, area: "carro"),
        .init(chave: "carro_taxas", nome: "IPVA, licenciamento e multas", icone: "doc.text.fill", corHex: "0369A1", grupo: .essencial, area: "carro"),
        // Transporte
        .init(chave: "apps_transporte", nome: "Uber e táxi", icone: "figure.wave", corHex: "22D3EE", grupo: .estiloDeVida, area: "transporte"),
        .init(chave: "transporte", nome: "Transporte público", icone: "tram.fill", corHex: "0891B2", grupo: .essencial, area: "transporte"),
        // Saúde
        .init(chave: "farmacia", nome: "Farmácia", icone: "pills.fill", corHex: "F87171", grupo: .essencial, area: "saude"),
        .init(chave: "plano_saude", nome: "Plano de saúde", icone: "heart.text.square.fill", corHex: "EF4444", grupo: .essencial, area: "saude"),
        .init(chave: "saude", nome: "Consultas e exames", icone: "cross.case.fill", corHex: "E5484D", grupo: .essencial, area: "saude"),
        .init(chave: "cuidados", nome: "Cuidados pessoais", icone: "sparkles", corHex: "D946EF", grupo: .estiloDeVida, area: "saude"),
        // Esportes
        .init(chave: "academia", nome: "Academia", icone: "dumbbell.fill", corHex: "FB7185", grupo: .estiloDeVida, area: "esportes"),
        .init(chave: "lutas", nome: "Lutas", icone: "figure.martial.arts", corHex: "E11D48", grupo: .estiloDeVida, area: "esportes"),
        .init(chave: "esportes", nome: "Outros esportes e aulas", icone: "figure.run", corHex: "FDA4AF", grupo: .estiloDeVida, area: "esportes"),
        .init(chave: "equipamento_esportivo", nome: "Equipamento esportivo", icone: "sportscourt.fill", corHex: "BE123C", grupo: .estiloDeVida, area: "esportes"),
        // Assinaturas
        .init(chave: "streaming", nome: "Streaming", icone: "play.tv.fill", corHex: "A855F7", grupo: .estiloDeVida, area: "assinaturas"),
        .init(chave: "apps_ia", nome: "Apps e IA", icone: "cpu.fill", corHex: "C084FC", grupo: .estiloDeVida, area: "assinaturas"),
        .init(chave: "assinaturas", nome: "Outras assinaturas", icone: "arrow.triangle.2.circlepath", corHex: "9333EA", grupo: .estiloDeVida, area: "assinaturas"),
        // Compras
        .init(chave: "roupas", nome: "Roupas e calçados", icone: "tshirt.fill", corHex: "FBBF24", grupo: .estiloDeVida, area: "compras"),
        .init(chave: "eletronicos", nome: "Eletrônicos", icone: "desktopcomputer", corHex: "F59E0B", grupo: .estiloDeVida, area: "compras"),
        .init(chave: "compras", nome: "Compras em geral", icone: "bag.fill", corHex: "EAB308", grupo: .estiloDeVida, area: "compras"),
        .init(chave: "presentes", nome: "Presentes e doações", icone: "gift.fill", corHex: "F43F5E", grupo: .estiloDeVida, area: "compras"),
        .init(chave: "pets", nome: "Pets", icone: "pawprint.fill", corHex: "A16207", grupo: .estiloDeVida, area: "compras"),
        // Lazer e viagem
        .init(chave: "bares", nome: "Bares e baladas", icone: "wineglass.fill", corHex: "F472B6", grupo: .estiloDeVida, area: "lazer"),
        .init(chave: "lazer", nome: "Lazer e ingressos", icone: "theatermasks.fill", corHex: "EC4899", grupo: .estiloDeVida, area: "lazer"),
        .init(chave: "jogos", nome: "Jogos", icone: "gamecontroller.fill", corHex: "DB2777", grupo: .estiloDeVida, area: "lazer"),
        .init(chave: "viagem", nome: "Viagem", icone: "airplane", corHex: "06B6D4", grupo: .estiloDeVida, area: "lazer"),
        // Educação
        .init(chave: "faculdade", nome: "Faculdade", icone: "graduationcap.fill", corHex: "7C5CFC", grupo: .essencial, area: "educacao"),
        .init(chave: "cursos", nome: "Cursos", icone: "text.book.closed.fill", corHex: "8B5CF6", grupo: .essencial, area: "educacao"),
        .init(chave: "livros", nome: "Livros e material", icone: "books.vertical.fill", corHex: "A78BFA", grupo: .essencial, area: "educacao"),
        .init(chave: "educacao", nome: "Escola e outros", icone: "book.closed.fill", corHex: "6D28D9", grupo: .essencial, area: "educacao"),
        // Taxas, impostos e seguros
        .init(chave: "seguros", nome: "Seguros", icone: "shield.fill", corHex: "5B6B8C", grupo: .essencial, area: "financeiro"),
        .init(chave: "impostos", nome: "Impostos", icone: "building.columns.fill", corHex: "64748B", grupo: .financeiro, area: "financeiro"),
        .init(chave: "tarifas", nome: "Tarifas e juros", icone: "percent", corHex: "94A3B8", grupo: .financeiro, area: "financeiro"),
        .init(chave: "emprestimos", nome: "Empréstimos e financiamentos", icone: "banknote.fill", corHex: "78716C", grupo: .financeiro, area: "financeiro"),
        // Outros
        .init(chave: "outros", nome: "Outros", icone: "ellipsis.circle.fill", corHex: "8B93A1", grupo: .estiloDeVida, area: "outros"),
        // Receitas
        .init(chave: "salario", nome: "Salário", icone: "briefcase.fill", corHex: "17B26A", grupo: .receita, area: "receitas"),
        .init(chave: "freelas", nome: "Freelas e serviços", icone: "laptopcomputer", corHex: "22C55E", grupo: .receita, area: "receitas"),
        .init(chave: "rendimentos", nome: "Rendimentos", icone: "chart.line.uptrend.xyaxis", corHex: "10B981", grupo: .receita, area: "receitas"),
        .init(chave: "reembolsos", nome: "Reembolsos", icone: "arrow.uturn.backward.circle.fill", corHex: "14B8A6", grupo: .receita, area: "receitas"),
        .init(chave: "outras_receitas", nome: "Outras receitas", icone: "plus.circle.fill", corHex: "84CC16", grupo: .receita, area: "receitas"),
        // Neutras (não entram em gasto nem renda)
        .init(chave: "investimentos", nome: "Aportes e resgates", icone: "chart.pie.fill", corHex: "0C47F9", grupo: .neutro, area: "movimentacoes"),
        .init(chave: "fatura", nome: "Pagamento de fatura", icone: "creditcard.fill", corHex: "6366F1", grupo: .neutro, area: "movimentacoes"),
        .init(chave: "transferencia", nome: "Transferência entre contas", icone: "arrow.left.arrow.right", corHex: "9CA3AF", grupo: .neutro, area: "movimentacoes"),
    ]

    private static let porChave: [String: CategoriaInfo] = Dictionary(uniqueKeysWithValues: todas.map { ($0.chave, $0) })
    private static let areaPorChave: [String: AreaCategoria] = Dictionary(uniqueKeysWithValues: areas.map { ($0.chave, $0) })

    public static func info(_ chave: String) -> CategoriaInfo {
        porChave[chave] ?? porChave["outros"]!
    }

    /// A área de uma categoria (pela chave da categoria).
    public static func area(de chave: String) -> AreaCategoria {
        areaPorChave[info(chave).area] ?? areaPorChave["outros"]!
    }

    /// A área pela própria chave ("carro", "casa"…).
    public static func area(_ chave: String) -> AreaCategoria {
        areaPorChave[chave] ?? areaPorChave["outros"]!
    }

    public static var despesas: [CategoriaInfo] { todas.filter { $0.ehDespesa } }
    public static var receitas: [CategoriaInfo] { todas.filter { $0.ehReceita } }

    /// Despesas agrupadas por área, na ordem de `areas` (para o seletor de categoria).
    public static var despesasPorArea: [(area: AreaCategoria, categorias: [CategoriaInfo])] {
        areas.compactMap { a in
            let lista = despesas.filter { $0.area == a.chave }
            return lista.isEmpty ? nil : (a, lista)
        }
    }

    /// Contas de consumo: o valor muda de um mês para o outro, e reajuste nelas interessa.
    public static let contasDeConsumo: Set<String> = ["contas", "luz", "agua_gas", "internet", "celular"]
}

// MARK: - Categorizador

public enum OrigemCategoria: Sendable {
    case regraDoUsuario, palavraChave, categoriaDoBanco, padrao
}

public struct ResultadoCategoria: Sendable {
    public var chave: String
    public var origem: OrigemCategoria
    public var interno: Bool
    /// De 0 a 100: quanto dá para confiar nessa categoria. Só em memória; serve para ordenar o que merece conferência.
    public var confianca: Int = 50
}

public enum Categorizador {
    // Palavras inteiras. Terminando em "*" casa por prefixo ("psicolog*" → psicologa, psicologia).
    // Cada termo tem um peso (ver `Termo.peso`): frase vale mais que palavra, palavra mais que prefixo.
    // Ganha a categoria com o termo mais pesado; em empate, a que vem antes nesta lista
    // (por isso delivery vem antes de restaurante e Mercado Livre antes de mercado).
    static let palavras: [(String, [String])] = [
        // Movimentações e receitas: pesam mais, porque "ESTORNO COMPRA MERCADOLIVRE" é estorno, não compra.
        ("fatura", ["pagamento da fatura", "pagamento de fatura", "pgto fatura", "pagamento fatura", "pag fatura",
                    "fatura cartao", "fatura do cartao", "pagamento recebido", "pagamento cartao", "pagto fatura",
                    "pagto cartao", "pagamento de cartao", "fatura itaucard", "fatura nubank"]),
        ("investimentos", ["aplicacao", "resgate", "rdb", "cdb", "lci", "lca", "tesouro direto", "tesouro selic",
                           "tesouro ipca", "tesouro prefixado", "invest*", "corretora", "xp investimentos",
                           "btg pactual", "nuinvest", "clear corretora", "rico investimentos", "previdencia",
                           "compra de acoes", "b3 s a"]),
        ("transferencia", ["transferencia entre contas", "transf entre contas", "mesma titularidade",
                           "conta propria", "transferencia propria"]),
        ("salario", ["salario", "folha de pagamento", "folha pgto", "proventos", "remuneracao", "13o salario",
                     "decimo terceiro", "adiantamento salarial"]),
        ("rendimentos", ["rendimento*", "dividendo*", "jcp", "juros sobre capital", "cashback", "juros recebidos"]),
        ("reembolsos", ["reembolso", "estorno", "devolucao", "cancelamento compra"]),

        // Impostos, taxas e dívidas
        ("carro_taxas", ["ipva", "licenciamento", "detran", "dpvat", "multa de transito", "infracao de transito",
                         "multa transito", "auto de infracao", "crlv", "cnh"]),
        ("impostos", ["darf", "das mei", "simples nacional", "irpf", "iptu", "receita federal", "gru simples", "inss",
                      "fgts", "itbi", "issqn"]),
        ("emprestimos", ["emprestimo", "financiamento", "consignado", "parcela financiamento", "refinanciamento", "fies"]),
        ("tarifas", ["tarifa*", "anuidade", "iof", "juros", "encargos", "manutencao de conta", "cesta de servicos",
                     "taxa de manutencao", "taxa de servico", "mora", "multa por atraso", "multa atraso"]),

        // Casa
        ("aluguel", ["aluguel", "imobiliaria", "quintoandar", "quinto andar"]),
        ("condominio", ["condominio"]),
        ("moradia", ["leroy merlin", "tok stok", "tokstok", "telhanorte", "c c c", "madeiramadeira", "faxina",
                     "diarista", "chaveiro", "dedetizacao", "material de construcao", "materiais de construcao",
                     "ferragens", "marcenaria", "vidracaria", "eletricista", "encanador", "ikea", "mobly", "camicado",
                     "etna", "casas bahia moveis"]),
        ("luz", ["enel", "light", "cpfl", "cemig", "copel", "energisa", "equatorial", "neoenergia", "energia",
                 "celesc", "coelba", "celpe", "elektro", "edp"]),
        ("agua_gas", ["sabesp", "cedae", "copasa", "sanepar", "comgas", "naturgy", "ultragaz", "agua e esgoto",
                      "embasa", "caesb", "compesa", "casan", "corsan", "saneamento", "supergasbras", "liquigas",
                      "consigaz"]),
        ("internet", ["oi fibra", "net claro", "claro net", "claro tv", "internet", "vero internet", "vivo fibra",
                      "vivo fixo", "banda larga", "sky tv", "sky servicos", "brisanet", "starlink"]),
        ("celular", ["claro", "vivo", "tim", "telefonia", "telefonica", "recarga celular", "recarga de celular"]),
        ("seguros", ["porto seguro", "tokio marine", "azul seguros", "seguro*", "sulamerica seguros", "liberty seguros",
                     "bradesco seguros", "allianz", "mapfre", "hdi seguros"]),

        // Assinaturas
        ("streaming", ["netflix", "spotify", "amazon prime", "prime video", "disney", "disney plus", "hbo",
                       "hbo max", "max com", "stream max", "globoplay", "youtube premium", "youtube", "deezer",
                       "paramount", "crunchyroll", "telecine", "apple music", "apple tv", "premiere", "mubi", "tidal",
                       "twitch", "audible"]),
        ("apps_ia", ["chatgpt", "openai", "anthropic", "claude ai", "claude", "notion", "figma", "github", "adobe",
                     "microsoft 365", "canva", "dropbox", "1password", "cursor", "vercel", "supabase",
                     "midjourney", "perplexity", "lovable", "replit", "icloud", "google one", "google storage",
                     "google workspace", "apple com bill", "apple services", "google play", "elevenlabs",
                     "runway", "capcut", "grok", "raycast", "framer", "webflow", "railway", "cloudflare",
                     "hostinger", "godaddy", "registro br", "apple developer", "setapp"]),
        ("assinaturas", ["duolingo", "linkedin premium", "tinder", "bumble", "assinatura*", "strava", "discord"]),

        // Alimentação (delivery antes de lanches e restaurantes: "IFOOD *RESTAURANTE" é delivery)
        ("delivery", ["ifood", "i food", "rappi", "uber eats", "ubereats", "99food", "99 food", "ze delivery",
                      "aiqfome", "delivery much", "keeta"]),
        ("lanches", ["lanchonete", "burger*", "mcdonald*", "mc donalds", "bk brasil", "burger king", "subway", "habib*",
                     "kfc", "popeyes", "bobs", "giraffas", "hamburgueria", "pastelaria", "espetinho", "hot dog",
                     "dogao", "lanches", "lanche", "fast food"]),
        ("padaria", ["padaria*", "panificadora", "cafe*", "cafeteria", "starbucks", "the coffee", "sorveteria",
                     "gelateria", "bacio di latte", "doceria", "confeitaria", "acai*", "kopenhagen",
                     "cacau show", "havanna"]),
        ("restaurantes", ["restaurante*", "pizzaria", "pizza", "outback", "churrascaria", "spoleto", "madero",
                          "coco bambu", "sushi*", "bar e restaurante", "bistro", "cantina", "emporio", "dominos",
                          "domino s", "china in box", "temakeria", "steakhouse", "poke", "galeto", "pizza hut",
                          "jeronimo", "ragazzo", "self service", "comida por quilo", "marmita*"]),
        // Mercado Livre e Mercado Pago não são mercado.
        ("compras", ["mercado livre", "mercadolivre", "mercadopago", "mercado pago", "mercado envios"]),
        ("mercado", ["carrefour", "pao de acucar", "extra hiper", "extra super*", "extra com", "assai", "atacadao",
                     "atacad*", "mercado*", "supermercado*", "super mercado", "hipermercado*", "hortifruti", "sams club",
                     "zaffari", "mambo", "oba hortifruti", "st marche", "guanabara", "mercadinho", "quitanda",
                     "acougue*", "peixaria", "sacolao", "makro", "big bompreco", "bompreco", "angeloni", "bistek",
                     "condor", "mart minas", "epa", "savegnago", "dia supermercado", "minimercado*", "emporio natural"]),

        // Carro
        ("combustivel", ["posto*", "auto posto", "shell", "shell box", "ipiranga", "abastece ai", "petrobras",
                         "br mania", "premmia", "combustivel", "combustiveis", "gasolina", "etanol", "gnv",
                         "diesel"]),
        ("estacionamento", ["estacionamento*", "estapar", "zona azul", "zul digital", "parking", "pedagio*",
                            "sem parar", "conectcar", "veloe", "taggy", "move mais", "ccr", "ecovias", "autoban",
                            "arteris", "valet"]),
        ("lavagem", ["lava rapido", "lava jato", "lavacao", "lava car", "lavagem", "estetica automotiva", "polimento",
                     "higienizacao automotiva", "ducha*"]),
        ("carro", ["oficina", "borracharia", "mecanica", "auto pecas", "autopecas", "auto center", "autocenter",
                   "auto eletrica", "pneu*", "dpaschoal", "troca de oleo", "funilaria", "martelinho", "alinhamento",
                   "despachante", "vistoria", "concessionaria", "insulfilm", "som automotivo", "revisao"]),

        // Transporte
        ("apps_transporte", ["uber", "uber trip", "uber do brasil", "99", "99app", "99 pop", "99 taxi", "cabify",
                             "indriver", "taxi", "blablacar"]),
        ("transporte", ["metro*", "bilhete unico", "bilhete digital", "top bilhete", "riocard", "cptm", "sptrans",
                        "onibus", "rodoviaria", "buser", "clickbus", "yellow bike", "tembici", "bike itau"]),

        // Saúde
        ("farmacia", ["drogasil", "droga raia", "raia", "drogaria*", "pacheco", "pague menos", "farmacia*",
                      "panvel", "drogal", "ultrafarma", "nissei", "extrafarma", "venancio"]),
        ("plano_saude", ["unimed", "amil", "hapvida", "sulamerica saude", "bradesco saude", "plano de saude",
                         "plano saude", "notredame", "intermedica", "prevent senior", "porto saude",
                         "alice saude", "qsaude", "odontoprev", "plano odonto*"]),
        ("saude", ["laboratorio*", "fleury", "dasa", "lavoisier", "delboni", "sabin", "hospital*", "clinica*",
                   "dentista*", "odonto*", "ortodont*", "dermato*", "psicolog*", "terapia", "medic*", "consulta",
                   "exame*", "fisioterapia", "nutricion*", "otica*", "oculos"]),

        // Esportes
        ("lutas", ["jiu jitsu", "jiujitsu", "bjj", "gracie*", "checkmat", "muay thai", "boxe", "boxing", "judo", "karate",
                   "taekwondo", "mma", "luta*", "artes marciais", "kickboxing", "capoeira", "krav maga", "wrestling"]),
        ("academia", ["smart fit", "smartfit", "bluefit", "bio ritmo", "selfit", "just fit", "justfit", "skyfit",
                      "panobianco", "gympass", "wellhub", "totalpass", "academia*", "musculacao"]),
        ("esportes", ["crossfit", "pilates", "natacao", "yoga", "beach tennis", "futevolei", "maratona", "ciclismo",
                      "escalada", "surf*", "futebol", "society", "personal trainer", "treino*", "esporte*", "corrida de rua"]),
        ("equipamento_esportivo", ["centauro", "decathlon", "netshoes", "nike", "adidas", "puma", "track field",
                                   "under armour", "mizuno", "olympikus", "asics", "new balance", "oakley", "speedo",
                                   "world tennis", "authentic feet", "artigos esportivos", "bicicletaria",
                                   "growth supplements", "suplemento*", "whey", "integralmedica", "max titanium",
                                   "dux nutrition", "probiotica"]),

        // Educação
        ("faculdade", ["faculdade", "universidade", "pos graduacao", "mba", "estacio", "anhanguera", "unip", "uninove",
                       "unopar", "fiap", "puc", "mackenzie", "fgv", "insper", "ibmec", "cruzeiro do sul", "unicesumar",
                       "uniasselvi", "anhembi", "fmu", "sao judas", "belas artes", "espm", "unicid", "faap", "unisa"]),
        ("cursos", ["curso*", "udemy", "coursera", "alura", "alura online", "rocketseat", "descomplica", "hotmart",
                    "kiwify", "dio", "idiomas", "wizard", "fisk", "cultura inglesa", "senac", "senai", "domestika",
                    "skillshare", "masterclass", "platzi", "origamid", "eduzz", "pluralsight", "linkedin learning",
                    "open english", "cambly", "preply", "italki", "ccaa", "yazigi", "cna", "aula*"]),
        ("livros", ["livraria*", "livro*", "kindle", "amazon kindle", "saraiva", "livraria cultura", "papelaria*", "kalunga",
                    "estante virtual", "material escolar", "material didatico"]),
        ("educacao", ["escola*", "colegio", "creche", "bercario", "mensalidade escolar"]),

        // Lazer e viagem
        ("bares", ["boteco", "balada", "bar", "pub", "karaoke", "cervejaria", "choperia", "chopp", "adega",
                   "distribuidora de bebidas", "night club", "lounge"]),
        ("jogos", ["steam*", "playstation", "psn", "xbox", "nintendo", "epic games", "riot games", "blizzard",
                   "ubisoft", "supercell", "garena", "free fire", "roblox", "game pass", "gamepass", "ps plus",
                   "playstation plus", "nuuvem", "gog com"]),
        ("lazer", ["cinema*", "cinemark", "kinoplex", "cinepolis", "uci cinemas", "ingresso*", "ingresse", "sympla",
                   "eventim", "ticketmaster", "tickets for fun", "blueticket", "ticket eventos", "livepass",
                   "clube*", "teatro", "show", "parque*", "boliche", "museu"]),

        // Compras
        ("roupas", ["shein", "zara", "renner", "c a", "cea", "riachuelo", "hering", "marisa", "pernambucanas",
                    "youcom", "vans", "lacoste", "dafiti", "farfetch", "havaianas", "arezzo", "calcados", "oqvestir",
                    "insider", "osklen", "aramis", "levis"]),
        ("eletronicos", ["kabum", "pichau", "terabyte", "fast shop", "apple store", "iplace", "samsung", "xiaomi",
                         "mi store", "dell", "logitech", "multilaser"]),
        ("compras", ["amazon", "amzn", "shopee", "aliexpress", "temu", "tiktok shop", "magalu", "magazine luiza",
                     "americanas", "casas bahia", "ponto frio", "havan", "daiso", "miniso",
                     "lojas*", "loja*", "shopping*"]),
        ("viagem", ["airbnb", "booking*", "decolar", "latam", "gol linhas", "azul linhas", "hotel*", "pousada*",
                    "cvc", "hurb", "rentcars", "localiza", "movida", "unidas", "passagem*", "aeroporto*",
                    "expedia", "hostel*", "trivago", "123 milhas", "maxmilhas", "airlines"]),
        ("cuidados", ["barbearia*", "salao*", "cabeleireir*", "boticario", "natura", "sephora", "beleza",
                      "estetica", "manicure", "depilacao", "perfumaria*", "granado", "avon", "o boticario"]),
        ("pets", ["petz", "cobasi", "petlove", "veterinari*", "pet shop", "petshop", "pet center", "agropet"]),
        ("presentes", ["doacao*", "vakinha", "presente*", "florista", "flores*", "floricultura", "caixa de bombons"]),
    ]

    /// Palavras que só dizem algo juntas: cada grupo precisa de pelo menos um termo presente (em qualquer ordem).
    /// "mensalidade" sozinha não é nada; com "uni" ou "fac" é faculdade; com "escola" é escola.
    static let compostos: [(String, [[String]])] = [
        ("faculdade", [["mensalidade", "matricula", "semestre", "rematricula"], ["faculdade", "universidade", "fac", "uni", "facul"]]),
        ("educacao", [["mensalidade", "matricula"], ["escola*", "colegio", "creche", "bercario"]]),
        ("esportes", [["tenis"], ["clube", "quadra*", "aula*", "arena*", "academia*", "escola*", "beach"]]),
        ("lazer", [["clube"], ["mensalidade", "socio", "associacao"]]),
        ("carro_taxas", [["multa", "multas"], ["transito", "detran", "radar", "velocidade", "infracao"]]),
        ("tarifas", [["multa", "multas"], ["atraso", "juros", "mora", "cartao", "fatura"]]),
    ]

    /// Mapeia o texto de categoria que o banco/Pluggy manda (árvore completa da Pluggy, em inglês, e os nomes
    /// em português que alguns bancos mandam). O mais específico vem antes: a primeira que casar vence.
    /// Trecho começando com "=" casa só a palavra inteira ("=rent" não casa "current").
    static let categoriaDoBanco: [(String, String)] = [
        // Comida
        ("food delivery", "delivery"), ("delivery", "delivery"),
        ("eating out", "restaurantes"), ("grocer", "mercado"), ("supermerc", "mercado"),
        ("restaurant", "restaurantes"), ("food", "restaurantes"), ("aliment", "restaurantes"),
        // Carro e transporte
        ("gas station", "combustivel"), ("fuel", "combustivel"), ("combust", "combustivel"),
        ("parking", "estacionamento"), ("toll", "estacionamento"), ("in vehicle payment", "estacionamento"),
        ("vehicle maintenance", "carro"), ("traffic ticket", "carro_taxas"), ("vehicle ownership", "carro_taxas"),
        ("vehicle insurance", "seguros"), ("vehicle financing", "emprestimos"), ("car rental", "viagem"),
        ("automotive", "carro"), ("vehicle", "carro"),
        ("taxi", "apps_transporte"), ("ride", "apps_transporte"), ("public transport", "transporte"),
        ("bus ticket", "transporte"), ("bicycle", "transporte"), ("transport", "transporte"),
        // Saúde e esporte
        ("pharm", "farmacia"), ("farmac", "farmacia"), ("dentist", "saude"), ("optometry", "saude"),
        ("hospital", "saude"), ("health insurance", "plano_saude"), ("gym", "academia"), ("fitness", "academia"),
        ("sports practice", "esportes"), ("wellness", "cuidados"), ("personal care", "cuidados"),
        ("health", "saude"), ("saude", "saude"),
        // Educação
        ("university", "faculdade"), ("student loan", "emprestimos"), ("online course", "cursos"),
        ("kindergarten", "educacao"), ("school", "educacao"), ("bookstore", "livros"), ("educ", "educacao"),
        // Assinaturas e digital
        ("video streaming", "streaming"), ("music streaming", "streaming"), ("streaming", "streaming"),
        ("gaming", "jogos"), ("digital service", "apps_ia"), ("software", "apps_ia"),
        ("subscri", "assinaturas"), ("assinat", "assinaturas"),
        // Compras
        ("sports goods", "equipamento_esportivo"), ("pet supplies", "pets"), ("=pet", "pets"), ("=pets", "pets"),
        ("cloth", "roupas"), ("electronic", "eletronicos"), ("kids and toys", "compras"), ("office suppl", "compras"),
        ("cashback", "rendimentos"), ("online shopping", "compras"), ("shopping", "compras"), ("compras", "compras"),
        // Lazer e viagem
        ("stadium", "lazer"), ("museum", "lazer"), ("cinema", "lazer"), ("ticket", "lazer"),
        ("entertain", "lazer"), ("leisure", "lazer"), ("lazer", "lazer"),
        ("gambl", "lazer"), ("online bet", "lazer"), ("lottery", "lazer"),
        ("airport", "viagem"), ("airline", "viagem"), ("accommodation", "viagem"), ("mileage", "viagem"),
        ("travel", "viagem"), ("viagem", "viagem"), ("hotel", "viagem"),
        // Impostos, taxas, seguros, dívidas (antes de "invest", "interest", "income")
        ("taxes on invest", "impostos"), ("tax on financial", "tarifas"), ("income tax", "impostos"),
        ("urban land", "impostos"), ("tax", "impostos"), ("imposto", "impostos"),
        ("life insurance", "seguros"), ("home insurance", "seguros"), ("insurance", "seguros"), ("seguro", "seguros"),
        ("account fee", "tarifas"), ("atm fee", "tarifas"), ("credit card fee", "tarifas"), ("bank fee", "tarifas"),
        ("late payment", "tarifas"), ("overdraft", "tarifas"), ("proceeds", "rendimentos"), ("dividend", "rendimentos"),
        ("interest", "tarifas"), ("fee", "tarifas"), ("tarif", "tarifas"), ("juros", "tarifas"),
        ("real estate financing", "emprestimos"), ("mortgage", "emprestimos"), ("loan", "emprestimos"),
        ("financing", "emprestimos"), ("emprest", "emprestimos"),
        // Casa
        ("electric", "luz"), ("energy", "luz"), ("water", "agua_gas"), ("=gas", "agua_gas"), ("utilit", "contas"),
        ("internet", "internet"), ("=tv", "internet"), ("mobile", "celular"), ("telecom", "celular"),
        ("=rent", "aluguel"), ("houseware", "moradia"), ("housing", "moradia"), ("moradia", "moradia"),
        // Receitas e movimentações
        ("salary", "salario"), ("salar", "salario"), ("entrepreneurial", "freelas"), ("retirement", "outras_receitas"),
        ("government aid", "outras_receitas"), ("non recurring income", "outras_receitas"),
        ("same person transfer", "transferencia"), ("credit card payment", "fatura"),
        ("automatic investment", "investimentos"), ("fixed income", "investimentos"), ("mutual fund", "investimentos"),
        ("variable income", "investimentos"), ("pension", "investimentos"), ("margin", "investimentos"),
        ("invest", "investimentos"), ("income", "outras_receitas"),
        ("gift", "presentes"), ("donation", "presentes"), ("refund", "reembolsos"),
        ("alimony", "outros"), ("blocked", "outros"),
    ]

    /// Contas de consumo que também têm "fatura" no nome.
    static let excecoesDeFatura = ["vivo", "claro", "tim", "oi", "enel", "light", "sabesp", "cpfl", "cemig", "copel",
                                   "internet", "energia", "agua", "luz", "gas", "telefone", "celular", "condominio",
                                   "escola", "faculdade", "net", "hospital", "plano de saude", "unimed", "amil"]

    /// Palavras que não identificam um estabelecimento e não podem virar regra.
    static let palavrasGenericas: Set<String> = [
        "compra", "debito", "credito", "cartao", "pix", "ted", "doc", "transferencia", "transf", "enviada", "enviado",
        "recebida", "recebido", "pagamento", "pagto", "pgto", "pag", "pelo", "para", "pela", "de", "da", "do", "das",
        "dos", "no", "na", "em", "com", "loja", "ltda", "sa", "me", "epp", "eireli", "conta", "fatura", "boleto",
        "saque", "deposito", "tarifa", "online", "app", "br", "brasil", "www", "parc", "parcela", "parcelado",
        "visa", "master", "mastercard", "elo", "amex", "internacional", "nacional",
    ]

    // MARK: Termos com peso

    struct Termo {
        let chave: String
        let texto: String
        let prefixo: Bool
        let peso: Int
        let ordem: Int
    }

    /// Chaves cujos termos pesam mais: movimentação de dinheiro e receita mandam sobre o nome da loja.
    private static let prioritarias: Set<String> = ["fatura", "investimentos", "transferencia", "salario", "rendimentos", "reembolsos"]

    static func peso(palavras: Int, prefixo: Bool, prioritaria: Bool) -> Int {
        palavras * 10 + (prefixo ? 0 : 3) + (prioritaria ? 20 : 0)
    }

    private static let termos: [Termo] = {
        var saida: [Termo] = []
        for (ordem, (chave, lista)) in palavras.enumerated() {
            for bruto in lista {
                let prefixo = bruto.hasSuffix("*")
                let texto = Texto.normalizar(prefixo ? String(bruto.dropLast()) : bruto)
                guard !texto.isEmpty else { continue }
                let n = texto.split(separator: " ").count
                saida.append(Termo(chave: chave, texto: texto, prefixo: prefixo,
                                   peso: peso(palavras: n, prefixo: prefixo, prioritaria: prioritarias.contains(chave)), ordem: ordem))
            }
        }
        return saida
    }()

    /// Casa por palavra inteira (ou frase inteira): "bar" não casa com "barbearia".
    public static func casaPadrao(_ textoNormalizado: String, _ padrao: String) -> Bool {
        guard !padrao.isEmpty else { return false }
        return (" " + textoNormalizado + " ").contains(" " + padrao + " ")
    }

    private static func casaTermo(_ h: String, _ t: Termo) -> Bool {
        t.prefixo ? h.contains(" " + t.texto) : h.contains(" " + t.texto + " ")
    }

    private static func contemPalavra(_ haystack: String, _ palavra: String) -> Bool {
        let h = " " + haystack + " "
        if palavra.hasSuffix("*") {
            return h.contains(" " + Texto.normalizar(String(palavra.dropLast())))
        }
        return h.contains(" " + Texto.normalizar(palavra) + " ")
    }

    private static func casaTrechoDoBanco(_ texto: String, _ trecho: String) -> Bool {
        trecho.hasPrefix("=") ? casaPadrao(texto, String(trecho.dropFirst())) : texto.contains(trecho)
    }

    /// A categoria que o banco sugere, pela nossa tabela. `nil` quando não reconhece.
    static func chaveDoBanco(_ banco: String?) -> String? {
        guard let b = banco, !b.isEmpty else { return nil }
        let nb = Texto.normalizar(b)
        return categoriaDoBanco.first { casaTrechoDoBanco(nb, $0.0) }?.1
    }

    /// A melhor categoria pelo dicionário: a de maior peso; em empate, a sugerida pelo banco; senão a que vem antes.
    /// Devolve também o peso e se houve disputa apertada (para a confiança).
    private static func pelasPalavras(_ texto: String, banco: String?) -> (chave: String, peso: Int, disputa: Bool)? {
        let h = " " + texto + " "
        var melhorPorChave: [String: (peso: Int, ordem: Int)] = [:]
        for t in termos where casaTermo(h, t) {
            if t.chave == "fatura", excecoesDeFatura.contains(where: { contemPalavra(texto, $0) }) { continue }
            if let atual = melhorPorChave[t.chave], atual.peso >= t.peso { continue }
            melhorPorChave[t.chave] = (t.peso, t.ordem)
        }
        for (ordem, (chave, grupos)) in compostos.enumerated() {
            let todos = grupos.allSatisfy { grupo in grupo.contains { contemPalavra(texto, $0) } }
            guard todos else { continue }
            let p = grupos.count * 10 + 5
            if let atual = melhorPorChave[chave], atual.peso >= p { continue }
            melhorPorChave[chave] = (p, palavras.count + ordem)
        }
        guard let topo = melhorPorChave.values.map(\.peso).max() else { return nil }
        let empatados = melhorPorChave.filter { $0.value.peso == topo }.sorted { $0.value.ordem < $1.value.ordem }
        let segundo = melhorPorChave.values.map(\.peso).filter { $0 < topo }.max() ?? 0
        let disputa = empatados.count > 1 || topo - segundo <= 3
        if empatados.count > 1, let b = banco, let escolhida = empatados.first(where: { $0.key == b }) {
            return (escolhida.key, topo, false)
        }
        return (empatados[0].key, topo, disputa)
    }

    public static func categorizar(descricao: String,
                                   estabelecimento: String? = nil,
                                   categoriaDoBanco banco: String? = nil,
                                   valorCentavos: Int,
                                   ehCartao: Bool = false,
                                   regras: [Regra] = []) -> ResultadoCategoria {
        let texto = Texto.normalizar([descricao, estabelecimento ?? ""].joined(separator: " "))
        // A chave de loja pode perder um número do meio ("Loja 123 Centro" → "loja centro"), e aí só o texto não casa.
        let chaveDeLoja = regras.isEmpty ? "" : Texto.estabelecimento(descricao, estabelecimento).chave

        // 1. Regras do usuário (as mais novas primeiro).
        for regra in regras.sorted(by: { $0.criadaEm > $1.criadaEm }) where !regra.padrao.isEmpty {
            if casaPadrao(texto, regra.padrao) || regra.padrao == chaveDeLoja {
                return ResultadoCategoria(chave: regra.categoriaChave, origem: .regraDoUsuario,
                                          interno: regra.marcarInterno || Categorias.info(regra.categoriaChave).grupo == .neutro,
                                          confianca: 100)
            }
        }

        let doBanco = chaveDoBanco(banco)

        // 2. Dicionário por peso (o banco desempata).
        if let r = pelasPalavras(texto, banco: doBanco) {
            let grupo = Categorias.info(r.chave).grupo
            // Pagamento de fatura só vira "interno" quando o par aparece no cartão (ver Conciliador.parearFaturas);
            // sem o cartão no app, o dinheiro realmente saiu.
            let interno = grupo == .neutro && r.chave != "fatura"
            var confianca = r.peso >= 20 ? 90 : (r.peso % 10 == 3 ? 75 : 65)
            if r.disputa { confianca -= 15 }
            if doBanco == r.chave { confianca = min(100, confianca + 10) }
            return ResultadoCategoria(chave: r.chave, origem: .palavraChave, interno: interno, confianca: confianca)
        }

        // 3. Categoria que o banco informou.
        if let chave = doBanco {
            let grupo = Categorias.info(chave).grupo
            return ResultadoCategoria(chave: chave, origem: .categoriaDoBanco, interno: grupo == .neutro, confianca: 55)
        }

        // 4. Padrão.
        if valorCentavos > 0 && !ehCartao {
            return ResultadoCategoria(chave: "outras_receitas", origem: .padrao, interno: false, confianca: 20)
        }
        return ResultadoCategoria(chave: "outros", origem: .padrao, interno: false, confianca: 10)
    }

    /// Texto curto e estável que identifica o estabelecimento — usado como padrão de regra e como chave de loja.
    /// Devolve "" quando não há nada específico o bastante (ex.: "Pix enviado", "Compra no débito").
    public static func padraoParaRegra(descricao: String, estabelecimento: String? = nil) -> String {
        Texto.estabelecimento(descricao, estabelecimento).chave
    }
}
