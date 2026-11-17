import SwiftData
import SwiftUI
import PrumoCore

// MARK: - Detalhe da conta

struct DetalheContaView: View {
    let contaID: String
    @Environment(\.modelContext) private var contexto
    @Query private var contas: [Conta]
    @Query private var faturas: [Fatura]
    @Query(sort: [SortDescriptor(\Lancamento.data, order: .reverse)]) private var lancamentos: [Lancamento]

    private var conta: Conta? { contas.first { $0.externalID == contaID } }

    var body: some View {
        if let c = conta {
            let minhasFaturas = faturas.filter { $0.contaID == contaID }.sorted { $0.vencimento > $1.vencimento }
            let recentes = lancamentos.filter { $0.contaID == contaID && $0.conciliadoComID == nil }.prefix(20)
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        // O nome é seu: toque e escreva ("Nubank do dia a dia"). O banco fica na etiqueta embaixo.
                        TextField(c.tipo.ehCartao ? "Nome do cartão" : "Nome da conta",
                                  text: Binding(get: { c.apelido ?? c.nome }, set: { novo in
                                      let limpo = novo.trimmingCharacters(in: .whitespaces)
                                      c.apelido = (limpo.isEmpty || limpo == c.nome) ? nil : novo
                                  }))
                            .font(.system(size: 24, weight: .semibold))
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                        Text([c.instituicao, c.tipo.nome, c.final4.map { "final \($0)" } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")).rotulo()
                        Text(c.tipo.ehCartao ? "Fatura atual" : "Saldo").rotulo().padding(.top, 14)
                        NumeroHeroi(centavos: c.tipo.ehCartao ? max(c.saldoCentavos, 0) : c.saldoCentavos, tamanho: 44)
                        if let uso = c.usoDoLimite {
                            BarraProgresso(valor: uso, cor: uso > 0.8 ? Tema.vermelho : Tema.acento, altura: 4).padding(.top, 4)
                            HStack {
                                Text("Disponível").font(.caption).foregroundStyle(.secondary)
                                Valor(centavos: c.disponivelCentavos ?? 0).font(.caption.weight(.medium))
                                Spacer()
                                Text("de").font(.caption).foregroundStyle(.secondary)
                                Valor(centavos: c.limiteCentavos ?? 0).font(.caption.weight(.medium))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

                if c.tipo.ehCartao, !minhasFaturas.isEmpty {
                    Section("Faturas") {
                        ForEach(minhasFaturas, id: \.externalID) { f in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Vence \(f.vencimento.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "pt_BR"))))")
                                        .font(.subheadline)
                                    if let fe = f.fechamento { Text("Fechou em \(fe.diaMesCurto)").font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Valor(centavos: f.totalCentavos).font(.subheadline.weight(.medium))
                                    Selo(texto: f.paga ? "Paga" : (f.vencimento < Date() ? "Vencida" : "Em aberto"),
                                         cor: f.paga ? Tema.acento : (f.vencimento < Date() ? Tema.vermelho : Tema.ambar))
                                }
                            }
                        }
                    }
                }

                Section("Preferências") {
                    Toggle("Somar no saldo do Início", isOn: Binding(get: { c.contaNoPatrimonio }, set: { c.contaNoPatrimonio = $0 }))
                    Toggle("Arquivar (esconder das telas)", isOn: Binding(get: { c.arquivada }, set: { c.arquivada = $0 }))
                    if c.manual {
                        HStack {
                            Text("Saldo")
                            Spacer()
                            TextField("0,00", value: Binding(get: { c.saldoCentavos.emReais }, set: { c.saldoCentavos = Dinheiro.centavos($0) }),
                                      format: .number.precision(.fractionLength(2)))
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 140)
                        }
                    }
                }

                Section {
                    NavigationLink(value: Destino.lancamentos(FiltroLancamentos(contaID: contaID, titulo: c.nomeExibicao))) {
                        Text("Ver todos os lançamentos")
                    }
                    ForEach(Array(recentes), id: \.externalID) { l in
                        LinhaLancamento(lancamento: l, nomeConta: nil, mostrarData: true)
                    }
                } header: { Text("Movimentação recente") }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fundo)
            .navigationTitle(c.nomeExibicao)
            .onDisappear { try? contexto.save() }
        } else {
            EstadoVazio(titulo: "Conta não encontrada", texto: "Ela pode ter sido removida na última atualização.")
                .padding(20)
        }
    }
}

struct NovaContaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var contexto
    @State private var nome = ""
    @State private var tipo: TipoConta = .dinheiro
    @State private var saldoTexto = ""

    var body: some View {
        Form {
            Section {
                TextField("Nome (ex.: Carteira, Reserva em casa)", text: $nome)
                Picker("Tipo", selection: $tipo) {
                    ForEach([TipoConta.dinheiro, .corrente, .poupanca, .investimento, .outro], id: \.self) { Text($0.nome).tag($0) }
                }
                TextField("Saldo atual (ex.: 350,00)", text: $saldoTexto)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            } footer: {
                Text("Contas manuais não atualizam sozinhas: você ajusta o saldo quando quiser. Servem para dinheiro em espécie ou bancos que não estão no Open Finance.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Nova conta")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }.semCapsulaNoMac()
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    let c = Conta(externalID: "manual-\(UUID().uuidString)", nome: nome, tipo: tipo, instituicao: "Manual")
                    c.manual = true
                    c.saldoCentavos = Dinheiro.ler(saldoTexto) ?? 0
                    c.ordem = 100
                    contexto.insert(c)
                    try? contexto.save()
                    dismiss()
                }
                .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty)
            }.semCapsulaNoMac()
        }
    }
}
