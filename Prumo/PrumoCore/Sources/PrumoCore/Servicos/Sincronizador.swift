import Foundation
import SwiftData

public struct ResumoSincronizacao: Sendable {
    public var inicio = Date()
    public var fim: Date?
    public var conexoes = 0
    public var lancamentosNovos = 0
    public var lancamentosAtualizados = 0
    public var conciliados = 0
    public var avisos: [String] = []
    public var erros: [String] = []
    /// Alguma conexão não terminou de atualizar (ou falhou): não apagamos nada com base nesses dados.
    public var parcial = false

    public var teveErro: Bool { !erros.isEmpty }
    public var textoCurto: String {
        if teveErro { return erros.first ?? "Falha ao atualizar" }
        if lancamentosNovos > 0 { return "\(lancamentosNovos) novo\(lancamentosNovos == 1 ? "" : "s")" }
        return "Tudo em dia"
    }
}

/// Busca os dados na Pluggy e grava no banco local. Roda no ator principal para o app
/// reagir às mudanças imediatamente; a rede acontece fora dele (dentro do `PluggyClient`).
@MainActor
public final class MotorDeSincronizacao {
    private let contexto: ModelContext
    private let cliente: PluggyClient
    private let janelaInicialDias: Int
    private let agora: () -> Date

    public init(contexto: ModelContext, cliente: PluggyClient, janelaInicialDias: Int = 400, agora: @escaping () -> Date = { Date() }) {
        self.contexto = contexto
        self.cliente = cliente
        self.janelaInicialDias = janelaInicialDias
        self.agora = agora
    }

    public func sincronizarTudo() async -> ResumoSincronizacao {
        var resumo = ResumoSincronizacao(inicio: agora())
        let conexoes = (try? contexto.fetch(FetchDescriptor<Conexao>(predicate: #Predicate { $0.ativa && !$0.demo }))) ?? []
        resumo.conexoes = conexoes.count
        if conexoes.isEmpty {
            resumo.avisos.append("Nenhuma conexão cadastrada. Adicione o ID de um item do Meu Pluggy em Ajustes.")
        }
        for conexao in conexoes {
            do { try await sincronizar(conexao, resumo: &resumo) }
            catch {
                resumo.parcial = true
                resumo.erros.append("\(conexao.nome.isEmpty ? "Conexão" : conexao.nome): \(error.localizedDescription)")
            }
        }
        do {
            resumo.conciliados = try Conciliador.conciliar(contexto)
            try Conciliador.parearFaturas(contexto)
            try Conciliador.parearTransferenciasProprias(contexto)
            try Higiene.deduplicar(contexto)
            // Foto parcial gravaria um patrimônio menor do que o real.
            if !resumo.parcial { try Patrimonio.registrarFoto(contexto, hoje: agora()) }
            try contexto.save()
        } catch {
            resumo.erros.append("Pós-processamento: \(error.localizedDescription)")
        }
        resumo.fim = agora()
        return resumo
    }

    // MARK: Uma conexão

    private func sincronizar(_ conexao: Conexao, resumo: inout ResumoSincronizacao) async throws {
        let item = try await cliente.item(conexao.itemID)
        conexao.nome = item.connector?.name ?? conexao.nome
        conexao.logoURL = item.connector?.imageUrl ?? conexao.logoURL
        conexao.corHex = item.connector?.primaryColor ?? conexao.corHex
        conexao.status = item.status ?? conexao.status
        conexao.ultimaAtualizacao = item.lastUpdatedAt ?? conexao.ultimaAtualizacao
        conexao.proximaAtualizacao = item.nextAutoSyncAt
        conexao.consentimentoExpiraEm = item.consentExpiresAt
        if conexao.precisaAtencao {
            resumo.avisos.append("\(conexao.nome): precisa de atenção (\(conexao.status)). Reconecte no Meu Pluggy.")
        }
        // Só uma atualização completa autoriza apagar/desativar coisas que "sumiram" da resposta.
        let completo = (item.status ?? "") == "UPDATED"
            && ((item.executionStatus ?? "SUCCESS").uppercased() == "SUCCESS")
        if !completo { resumo.parcial = true }

        let regras = (try? contexto.fetch(FetchDescriptor<Regra>())) ?? []

        // Contas
        let pluggyContas = try await cliente.contas(itemID: conexao.itemID)
        var contasLocais: [Conta] = []
        var mapeadas: [Mapeador.ContaMapeada] = []
        for pc in pluggyContas {
            let m = Mapeador.conta(pc)
            let idConta = m.externalID
            let existente = try contexto.fetch(FetchDescriptor<Conta>(predicate: #Predicate { $0.externalID == idConta })).first
            let conta = existente ?? {
                let nova = Conta(externalID: m.externalID, nome: m.nome, tipo: m.tipo)
                contexto.insert(nova)
                return nova
            }()
            conta.conexaoItemID = conexao.itemID
            conta.instituicao = conexao.nome
            conta.logoURL = conexao.logoURL
            conta.corHex = conexao.corHex
            conta.nome = m.nome
            conta.tipo = m.tipo
            conta.saldoCentavos = m.saldoCentavos
            conta.moeda = m.moeda
            conta.limiteCentavos = m.limiteCentavos
            conta.disponivelCentavos = m.disponivelCentavos
            conta.fechamentoFatura = m.fechamento
            conta.vencimentoFatura = m.vencimento
            conta.minimoFaturaCentavos = m.minimoCentavos
            conta.bandeira = m.bandeira
            conta.final4 = m.final4
            conta.atualizadaEm = agora()
            contasLocais.append(conta)
            mapeadas.append(m)
        }

        // Lançamentos e faturas, conta por conta (uma falha não derruba as demais)
        for (m, conta) in zip(mapeadas, contasLocais) {
            do {
                try await sincronizarLancamentos(conta: conta, documento: m.documentoTitular, nome: m.nomeTitular,
                                                 regras: regras, completo: completo, resumo: &resumo)
            } catch {
                resumo.parcial = true
                resumo.erros.append("\(conta.nomeExibicao): \(error.localizedDescription)")
            }
            if conta.tipo == .cartao {
                if let faturas = try? await cliente.faturas(contaID: conta.externalID) {
                    aplicar(faturas: faturas, conta: conta)
                }
            }
        }

        // Investimentos e empréstimos: nem toda instituição tem; falha aqui não é erro da conexão.
        if let invs = try? await cliente.investimentos(itemID: conexao.itemID) {
            aplicar(investimentos: invs, conexao: conexao, desativarAusentes: completo)
        }
        if let loans = try? await cliente.emprestimos(itemID: conexao.itemID) {
            aplicar(emprestimos: loans, conexao: conexao)
        }
        try contexto.save()
    }

    private func sincronizarLancamentos(conta: Conta, documento: String?, nome: String?, regras: [Regra],
                                        completo: Bool, resumo: inout ResumoSincronizacao) async throws {
        let contaID = conta.externalID
        let origem = OrigemLancamento.openFinance.rawValue
        let existentes = try contexto.fetch(FetchDescriptor<Lancamento>(predicate: #Predicate { $0.contaID == contaID && $0.origemRaw == origem }))
        let hoje = agora()
        let teto = Datas.somar(dias: -janelaInicialDias, a: hoje)
        // Âncora = o mais recente que JÁ aconteceu (parcelas futuras pendentes não contam).
        let maisRecente = existentes.map(\.data).filter { $0 <= hoje }.max()
        // 30 dias de sobreposição: pegam lançamentos que mudam de "pendente" para "efetivado".
        let desde = maisRecente.map { max(Datas.somar(dias: -30, a: $0), teto) } ?? teto

        let recebidas = try await cliente.transacoes(contaID: contaID, desde: desde)
        var porID = Dictionary(existentes.map { ($0.externalID, $0) }, uniquingKeysWith: { a, _ in a })
        var vistos = Set<String>()

        for t in recebidas {
            let m = Mapeador.lancamento(t, contaID: contaID, tipoConta: conta.tipo, documentoTitular: documento, nomeTitular: nome)
            vistos.insert(m.externalID)
            let lanc: Lancamento
            if let l = porID[m.externalID] {
                lanc = l
                resumo.lancamentosAtualizados += 1
            } else {
                lanc = Lancamento(externalID: m.externalID, contaID: contaID, data: m.data, descricao: m.descricao, valorCentavos: m.valorCentavos, origem: .openFinance)
                contexto.insert(lanc)
                porID[m.externalID] = lanc
                resumo.lancamentosNovos += 1
            }
            lanc.data = m.data
            lanc.descricao = m.descricao
            lanc.descricaoOriginal = m.descricaoOriginal
            lanc.estabelecimento = m.estabelecimento
            lanc.valorCentavos = m.valorCentavos
            lanc.moeda = m.moeda
            lanc.status = m.pendente ? .pendente : .efetivado
            lanc.parcelaAtual = m.parcelaAtual
            lanc.totalParcelas = m.totalParcelas
            lanc.faturaID = m.faturaID
            lanc.cartaoCarteira = m.cartaoFinal4
            lanc.atualizadoEm = agora()
            let c = Mapeador.classificar(m, tipoConta: conta.tipo, regras: regras)
            if !lanc.categoriaManual { lanc.categoriaChave = c.categoria }
            if !lanc.internoManual {
                // Categoria escolhida por você manda: neutra (transferência, fatura, aporte) = interno; senão, não.
                lanc.interno = lanc.categoriaManual ? Categorias.info(lanc.categoriaChave).grupo == .neutro : c.interno
            }
        }

        // Pendentes que sumiram do banco saem daqui também — mas só com atualização completa e resposta não vazia.
        guard completo, !recebidas.isEmpty else { return }
        for l in existentes where l.status == .pendente && l.data >= desde && !vistos.contains(l.externalID) {
            if l.categoriaManual || l.notas != nil || l.ignorado || l.internoManual {
                l.ignorado = true   // você mexeu: não apagamos, só tiramos dos relatórios
            } else {
                contexto.delete(l)
            }
        }
    }

    private func aplicar(faturas: [PluggyFatura], conta: Conta) {
        let contaID = conta.externalID
        for pf in faturas {
            let id = pf.id
            let existente = try? contexto.fetch(FetchDescriptor<Fatura>(predicate: #Predicate { $0.externalID == id })).first
            let f = existente ?? {
                let nova = Fatura(externalID: id, contaID: contaID, vencimento: Datas.diaCivil(deUTC: pf.dueDate), totalCentavos: 0)
                contexto.insert(nova)
                return nova
            }()
            f.contaID = contaID
            f.vencimento = Datas.diaCivil(deUTC: pf.dueDate)
            f.fechamento = pf.billClosingDate.map(Datas.diaCivil(deUTC:))
            f.totalCentavos = Dinheiro.centavos(pf.totalAmount ?? 0)
            f.minimoCentavos = pf.minimumPaymentAmount.map(Dinheiro.centavos)
            f.pagaCentavos = Dinheiro.centavos((pf.payments ?? []).compactMap(\.amount).reduce(0, +))
            f.atualizadaEm = agora()
        }
    }

    private func aplicar(investimentos: [PluggyInvestimento], conexao: Conexao, desativarAusentes: Bool) {
        let itemID = conexao.itemID
        let existentes = (try? contexto.fetch(FetchDescriptor<Investimento>(predicate: #Predicate { $0.conexaoItemID == itemID }))) ?? []
        var porID = Dictionary(existentes.map { ($0.externalID, $0) }, uniquingKeysWith: { a, _ in a })
        var vistos = Set<String>()
        for pi in investimentos {
            let m = Mapeador.investimento(pi)
            vistos.insert(m.externalID)
            let inv = porID[m.externalID] ?? {
                let novo = Investimento(externalID: m.externalID, nome: m.nome, classe: m.classe, saldoCentavos: m.saldoCentavos)
                contexto.insert(novo)
                porID[m.externalID] = novo
                return novo
            }()
            inv.conexaoItemID = itemID
            inv.instituicao = conexao.nome
            inv.nome = m.nome
            inv.classe = m.classe
            inv.subtipo = m.subtipo
            inv.saldoCentavos = m.saldoCentavos
            inv.aplicadoCentavos = m.aplicadoCentavos
            inv.lucroCentavos = m.lucroCentavos
            inv.quantidade = m.quantidade
            inv.valorCotaCentavos = m.valorCotaCentavos
            inv.taxaAnual = m.taxaAnual
            inv.rentabilidade12m = m.rentabilidade12m
            inv.rentabilidadeMes = m.rentabilidadeMes
            inv.vencimento = m.vencimento
            inv.emissor = m.emissor
            inv.codigo = m.codigo
            inv.ativo = true
            inv.atualizadoEm = agora()
        }
        // O que não veio mais foi resgatado/vendido — só se a atualização foi completa.
        guard desativarAusentes else { return }
        for inv in existentes where !vistos.contains(inv.externalID) && !inv.manual { inv.ativo = false }
    }

    private func aplicar(emprestimos: [PluggyEmprestimo], conexao: Conexao) {
        for pl in emprestimos {
            let id = pl.id
            let existente = try? contexto.fetch(FetchDescriptor<Emprestimo>(predicate: #Predicate { $0.externalID == id })).first
            let e = existente ?? {
                let novo = Emprestimo(externalID: id, nome: pl.productName ?? "Empréstimo", contratadoCentavos: 0)
                contexto.insert(novo)
                return novo
            }()
            e.conexaoItemID = conexao.itemID
            e.instituicao = conexao.nome
            e.nome = pl.productName ?? e.nome
            e.contratadoCentavos = Dinheiro.centavos(pl.contractAmount ?? 0)
            e.vencimentoFinal = pl.dueDate.map(Datas.diaCivil(deUTC:))
            e.custoEfetivoTotal = pl.CET

            let parcelas = pl.installments
            let total = parcelas?.totalNumberOfInstallments ?? 0
            let pagas = parcelas?.paidInstallments ?? 0
            let restantes = parcelas?.contractRemainingNumber ?? (total > 0 ? max(0, total - pagas) : nil)
            e.parcelasRestantes = restantes

            // Saldo devedor: o que o banco informa vale; senão, estimativa pelo valor contratado.
            if let saldo = pl.payments?.contractOutstandingBalance {
                e.saldoDevedorCentavos = Dinheiro.centavos(saldo)
                if let r = restantes, r > 0 { e.parcelaCentavos = Dinheiro.centavos(saldo) / r }
            } else if total > 0 {
                let parcela = e.contratadoCentavos / total
                e.parcelaCentavos = parcela
                e.saldoDevedorCentavos = parcela * (restantes ?? 0)
            }
            // Próximo vencimento: primeira parcela + parcelas já pagas (periodicidade mensal).
            if let primeira = pl.firstInstallmentDueDate, restantes != nil, (restantes ?? 0) > 0 {
                let base = Datas.diaCivil(deUTC: primeira)
                var proximo = Datas.somar(meses: pagas, a: base)
                // Se por atraso já passou, mostra a mais próxima futura.
                var guarda = 0
                while proximo < Datas.inicioDoDia(agora()), guarda < 600 { proximo = Datas.somar(meses: 1, a: proximo); guarda += 1 }
                e.proximoVencimento = proximo
            }
            e.atualizadoEm = agora()
        }
    }
}
