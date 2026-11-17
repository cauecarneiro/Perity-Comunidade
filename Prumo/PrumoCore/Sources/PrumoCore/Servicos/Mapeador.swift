import Foundation

/// Converte os formatos da Pluggy nos do app. Funções puras: fáceis de testar com JSON de exemplo.
public enum Mapeador {

    public struct ContaMapeada: Sendable, Equatable {
        public var externalID: String
        public var nome: String
        public var tipo: TipoConta
        public var saldoCentavos: Int
        public var moeda: String
        public var limiteCentavos: Int?
        public var disponivelCentavos: Int?
        public var fechamento: Date?
        public var vencimento: Date?
        public var minimoCentavos: Int?
        public var bandeira: String?
        public var final4: String?
        public var documentoTitular: String?
        public var nomeTitular: String?
    }

    public struct LancamentoMapeado: Sendable, Equatable {
        public var externalID: String
        public var contaID: String
        public var data: Date
        public var descricao: String
        public var descricaoOriginal: String?
        public var estabelecimento: String?
        public var valorCentavos: Int
        public var moeda: String
        public var categoriaDoBanco: String?
        public var pendente: Bool
        public var parcelaAtual: Int?
        public var totalParcelas: Int?
        public var faturaID: String?
        public var transferenciaPropria: Bool
        public var cartaoFinal4: String?
    }

    public struct InvestimentoMapeado: Sendable, Equatable {
        public var externalID: String
        public var nome: String
        public var classe: ClasseAtivo
        public var subtipo: String?
        public var saldoCentavos: Int
        public var aplicadoCentavos: Int?
        public var lucroCentavos: Int?
        public var quantidade: Double?
        public var valorCotaCentavos: Int?
        public var taxaAnual: Double?
        public var rentabilidade12m: Double?
        public var rentabilidadeMes: Double?
        public var vencimento: Date?
        public var emissor: String?
        public var codigo: String?
    }

    // MARK: Contas

    public static func conta(_ c: PluggyConta) -> ContaMapeada {
        let tipo: TipoConta
        switch (c.subtype ?? "").uppercased() {
        case "CREDIT_CARD": tipo = .cartao
        case "SAVINGS_ACCOUNT": tipo = .poupanca
        case "CHECKING_ACCOUNT", "CHECKINGS_ACCOUNT": tipo = .corrente
        default: tipo = (c.type ?? "").uppercased() == "CREDIT" ? .cartao : .corrente
        }
        let nome = (c.marketingName?.isEmpty == false ? c.marketingName! : c.name) ?? "Conta"
        let final4: String? = {
            guard let n = c.number else { return nil }
            let d = n.filter(\.isNumber)
            return d.count >= 4 ? String(d.suffix(4)) : nil
        }()
        return ContaMapeada(
            externalID: c.id,
            nome: nome,
            tipo: tipo,
            saldoCentavos: Dinheiro.centavos(c.balance ?? 0),
            moeda: c.currencyCode ?? "BRL",
            limiteCentavos: c.creditData?.creditLimit.map(Dinheiro.centavos),
            disponivelCentavos: c.creditData?.availableCreditLimit.map(Dinheiro.centavos),
            fechamento: c.creditData?.balanceCloseDate.map(Datas.diaCivil(deUTC:)),
            vencimento: c.creditData?.balanceDueDate.map(Datas.diaCivil(deUTC:)),
            minimoCentavos: c.creditData?.minimumPayment.map(Dinheiro.centavos),
            bandeira: c.creditData?.brand,
            final4: final4,
            documentoTitular: c.taxNumber?.filter(\.isNumber),
            nomeTitular: c.owner
        )
    }

    // MARK: Lançamentos

    /// Positivo = entrou dinheiro. Pela Pluggy, `type` manda; em cartão, "amount" positivo é compra.
    public static func valorAssinado(_ t: PluggyTransacao, tipoConta: TipoConta) -> Int {
        // Compra em moeda estrangeira: vale o que foi cobrado na moeda da conta (reais), não o valor em dólar.
        let valor = t.amountInAccountCurrency ?? t.amount
        let c = Dinheiro.centavos(abs(valor))
        switch (t.type ?? "").uppercased() {
        case "DEBIT": return -c
        case "CREDIT": return c
        default:
            if tipoConta == .cartao { return valor >= 0 ? -c : c }
            return valor >= 0 ? c : -c
        }
    }

    public static func lancamento(_ t: PluggyTransacao, contaID: String, tipoConta: TipoConta,
                                  documentoTitular: String?, nomeTitular: String? = nil) -> LancamentoMapeado {
        let descricao = (t.description?.isEmpty == false ? t.description! : (t.descriptionRaw ?? "Lançamento"))
        let estabelecimento = t.merchant?.name ?? t.merchant?.businessName

        // Pix/TED entre contas do mesmo titular. O "outro lado" é o recebedor num débito e o pagador num crédito.
        var propria = false
        let ehDebito = t.type?.uppercased() == "DEBIT"
        let ehCredito = t.type?.uppercased() == "CREDIT"
        let outroLado = ehDebito ? t.paymentData?.receiver : (ehCredito ? t.paymentData?.payer : nil)
        if let outro = outroLado {
            if let doc = documentoTitular, doc.count >= 11,
               let d = outro.documentNumber?.value?.filter(\.isNumber), !d.isEmpty {
                propria = d == doc
                    // Documento mascarado ("***.456.789-**"): compara só os dígitos que aparecem.
                    || (d.count >= 6 && doc.contains(d))
            }
            if !propria, let meu = nomeTitular.map(Texto.normalizar), meu.split(separator: " ").count >= 2,
               let nome = outro.name.map(Texto.normalizar), nome == meu {
                propria = true
            }
        }

        return LancamentoMapeado(
            externalID: t.id,
            contaID: contaID,
            // Vale a data do lançamento (a da fatura), não a da compra: parcela 3/10 pertence ao mês em que cobra.
            data: Datas.diaCivil(deUTC: t.date),
            descricao: descricao,
            descricaoOriginal: t.descriptionRaw,
            estabelecimento: estabelecimento,
            valorCentavos: valorAssinado(t, tipoConta: tipoConta),
            moeda: t.currencyCode ?? "BRL",
            categoriaDoBanco: t.category,
            pendente: (t.status ?? "").uppercased() == "PENDING",
            parcelaAtual: t.creditCardMetadata?.installmentNumber,
            totalParcelas: t.creditCardMetadata?.totalInstallments,
            faturaID: t.creditCardMetadata?.billId,
            transferenciaPropria: propria,
            cartaoFinal4: t.creditCardMetadata?.cardNumber.map { String($0.filter(\.isNumber).suffix(4)) }
        )
    }

    /// Decide categoria e se o lançamento é "interno" (não é gasto nem renda).
    public static func classificar(_ l: LancamentoMapeado, tipoConta: TipoConta, regras: [Regra]) -> (categoria: String, interno: Bool) {
        let r = Categorizador.categorizar(
            descricao: l.descricao,
            estabelecimento: l.estabelecimento,
            categoriaDoBanco: l.categoriaDoBanco,
            valorCentavos: l.valorCentavos,
            ehCartao: tipoConta.ehCartao,
            regras: regras
        )
        var categoria = r.chave
        var interno = r.interno

        if l.transferenciaPropria { interno = true; categoria = "transferencia" }

        // Dinheiro de empréstimo que entra é o principal da dívida, não renda.
        if l.valorCentavos > 0, categoria == "emprestimos", r.origem != .regraDoUsuario { interno = true }

        // Em cartão, entrada de dinheiro é pagamento da fatura (interno) ou estorno (devolução da compra).
        if tipoConta.ehCartao, l.valorCentavos > 0, r.origem != .regraDoUsuario {
            if categoria == "reembolsos" {
                interno = false
            } else {
                interno = true
                categoria = "fatura"
            }
        }
        return (categoria, interno)
    }

    // MARK: Investimentos

    public static func investimento(_ i: PluggyInvestimento) -> InvestimentoMapeado {
        // `amount` é o valor bruto atual (com imposto): só `amountOriginal` é o quanto foi aplicado.
        let aplicado = i.amountOriginal
        return InvestimentoMapeado(
            externalID: i.id,
            nome: i.name ?? "Investimento",
            classe: ClasseAtivo.de(type: i.type, subtype: i.subtype),
            subtipo: i.subtype,
            saldoCentavos: Dinheiro.centavos(i.balance ?? 0),
            aplicadoCentavos: aplicado.map(Dinheiro.centavos),
            lucroCentavos: i.amountProfit.map(Dinheiro.centavos),
            quantidade: i.quantity,
            valorCotaCentavos: i.value.map(Dinheiro.centavos),
            // A Pluggy manda as taxas em percentual (3,24 = 3,24%; o exemplo da documentação tem
            // lastMonthRate 0,24 e annualRate 3,24, coerentes entre si só como percentual).
            // Internamente guardamos como fração (0,0324), que é o que a interface formata.
            taxaAnual: (i.annualRate ?? i.fixedAnnualRate ?? i.rate).map { $0 / 100 },
            rentabilidade12m: i.lastTwelveMonthsRate.map { $0 / 100 },
            rentabilidadeMes: i.lastMonthRate.map { $0 / 100 },
            vencimento: i.dueDate.map(Datas.diaCivil(deUTC:)),
            emissor: i.issuer,
            codigo: i.code
        )
    }
}
