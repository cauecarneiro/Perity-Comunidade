import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import PrumoCore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Mostra só o começo e o fim do ID da conexão (o ID completo é tratado como dado sensível).
func itemIDMascarado(_ id: String) -> String {
    guard id.count > 10 else { return String(repeating: "•", count: id.count) }
    return "\(id.prefix(4))••••\(id.suffix(4))"
}

/// Copia um texto sensível por ação explícita do usuário: sem Área de Transferência Universal
/// (não vai para os outros aparelhos) e, no iPhone, expira em 2 minutos.
func copiarTextoSensivel(_ texto: String) {
    #if canImport(UIKit)
    UIPasteboard.general.setItems([[UTType.plainText.identifier: texto]],
                                  options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
    #elseif canImport(AppKit)
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(texto, forType: .string)
    // Convenção para gerenciadores de área de transferência não guardarem o item.
    pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    #endif
}

struct AjustesView: View {
    @Environment(EstadoApp.self) private var estado
    @Query private var conexoes: [Conexao]

    var body: some View {
        Form {
            Section {
                NavigationLink { ConectarBancosView() } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conectar bancos (Meu Pluggy)")
                        Text(estado.temCredenciais
                             ? "\(conexoes.filter { !$0.demo }.count) conexão(ões) · \(estado.buscaBancos ? "este aparelho busca" : "este aparelho só recebe")"
                             : "Open Finance · limites conforme a Pluggy")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                NavigationLink { ImportarExtratoView() } label: {
                    Text("Importar extrato (OFX ou CSV)")
                }
            } header: { Text("Bancos e cartões") }

            Section {
                NavigationLink { ApplePayView() } label: {
                    Text("Apple Pay em tempo real")
                }
            } header: { Text("Tempo real") } footer: {
                Text("O Open Finance atualiza em ciclos (o intervalo depende da Pluggy). O Apple Pay avisa o Perity no instante em que você paga.")
            }

            #if os(iOS)
            Section {
                NavigationLink { ConferirView() } label: { Text("Conferir categorias") }
            } header: { Text("Categorias") } footer: {
                Text("Veja onde cada loja caiu e corrija o que estiver errado. A correção vira regra: arruma as anteriores e vale para as próximas.")
            }
            #endif

            Section {
                ForEach(Secao.allCases) { s in
                    Toggle("Ocultar valores em \(s.titulo)", isOn: Binding(get: { estado.oculta(s) }, set: { estado.definirOcultar($0, em: s) }))
                }
            } header: { Text("Privacidade") } footer: {
                Text("Cada página tem o seu olho. O do Início vale também para contas, cartões, gastos e lançamentos, e para o widget. No iPhone, o app também borra a tela na lista de apps recentes.")
            }

            Section {
                if estado.modoDemo {
                    Text("Você está vendo dados de exemplo.")
                    Button("Sair do exemplo e apagar estes dados", role: .destructive) { estado.desativarDemo() }
                } else {
                    Button("Carregar dados de exemplo") { estado.ativarDemo() }
                }
            } header: { Text("Exemplo") } footer: {
                Text("Os dados de exemplo são fictícios e ficam separados dos seus. Apagar não mexe em nada seu.")
            }

            Section("Sobre") {
                LabeledContent("Versão", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                Text("Seus dados ficam neste aparelho e no seu iCloud. O Perity não tem servidor: só a Pluggy (que lê seus bancos com a sua autorização) vê os dados na rede.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Ajustes")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

// MARK: - Conectar bancos

struct ConectarBancosView: View {
    @Environment(EstadoApp.self) private var estado
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Conexao.criadaEm) private var conexoes: [Conexao]
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var novoItem = ""
    @State private var confirmarApagar = false

    private var reais: [Conexao] { conexoes.filter { !$0.demo } }

    var body: some View {
        @Bindable var estado = estado
        Form {
            Section {
                passo(1, "Crie a sua conta no Meu Pluggy e conecte seus bancos (a autorização de cada banco é feita no fluxo do Meu Pluggy).")
                Link("Abrir meu.pluggy.ai", destination: URL(string: "https://meu.pluggy.ai")!)
                passo(2, "No painel da Pluggy, crie uma aplicação e ative o conector “MeuPluggy”. Copie o Client ID e o Client Secret.")
                Link("Abrir dashboard.pluggy.ai", destination: URL(string: "https://dashboard.pluggy.ai")!)
                passo(3, "Em “Connect Account”, escolha MeuPluggy para cada banco. Copie o ID de cada item conectado.")
                passo(4, "Cole tudo abaixo. O segredo fica só no Keychain deste aparelho.")
            } header: { Text("Passo a passo") } footer: {
                Text("O plano, os limites de conexões e o intervalo de atualização dependem da Pluggy e podem mudar. Confira no site deles.")
            }

            Section {
                TextField("Client ID", text: $clientID)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                SecureField("Client Secret", text: $clientSecret)
                HStack {
                    Button("Salvar neste aparelho") {
                        estado.salvarCredenciais(clientID: clientID, clientSecret: clientSecret)
                        clientSecret = ""
                    }
                    .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty || clientSecret.isEmpty)
                    Spacer()
                    if estado.temCredenciais {
                        Label("Salvo", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(Tema.acento)
                    }
                }
                if estado.temCredenciais {
                    Button("Apagar credenciais deste aparelho", role: .destructive) { confirmarApagar = true }
                }
            } header: { Text("Credenciais da Pluggy") }

            Section {
                ForEach(reais, id: \.itemID) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Circle().fill(c.precisaAtencao ? Tema.vermelho : Tema.acento).frame(width: 8, height: 8)
                            Text(c.nome.isEmpty ? "Conexão" : c.nome).font(.subheadline.weight(.medium))
                        }
                        Text(itemIDMascarado(c.itemID)).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button("Copiar ID completo") { copiarTextoSensivel(c.itemID) }
                    }
                }
                .onDelete { idx in
                    for i in idx { contexto.delete(reais[i]) }
                    try? contexto.save()
                }
                HStack {
                    TextField("ID do item (cole aqui)", text: $novoItem)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    Button("Adicionar") {
                        let id = novoItem.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !id.isEmpty, !conexoes.contains(where: { $0.itemID == id }) else { return }
                        let c = Conexao(itemID: id, nome: "")
                        c.ordem = reais.count
                        contexto.insert(c)
                        try? contexto.save()
                        novoItem = ""
                    }
                    .disabled(novoItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: { Text("Bancos conectados") } footer: {
                Text("Cada ID é uma conexão (um banco). O nome aparece depois da primeira atualização.")
            }

            Section {
                Toggle("Este aparelho busca os dados nos bancos", isOn: $estado.buscaBancos)
                Button {
                    Task { await estado.atualizar() }
                } label: {
                    HStack {
                        Label("Testar e atualizar agora", systemImage: "arrow.triangle.2.circlepath")
                        if estado.atualizacao == .atualizando { Spacer(); ProgressView().controlSize(.small) }
                    }
                }
                .disabled(!estado.temCredenciais || reais.isEmpty || estado.atualizacao == .atualizando)

                if let r = estado.ultimoResumo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(r.lancamentosNovos) novos · \(r.lancamentosAtualizados) atualizados · \(r.conciliados) conciliados").font(.caption)
                        ForEach(r.avisos, id: \.self) { Text($0).font(.caption).foregroundStyle(Tema.ambar) }
                        ForEach(r.erros, id: \.self) { Text($0).font(.caption).foregroundStyle(Tema.vermelho) }
                    }
                }
            } header: { Text("Atualização") } footer: {
                Text("Deixe ligado em um aparelho só (o Mac). O outro recebe tudo pelo iCloud, sem repetir consultas.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Conectar bancos")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .formStyle(.grouped)
        #endif
        .confirmationDialog("Apagar as credenciais da Pluggy deste aparelho?", isPresented: $confirmarApagar, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) { estado.apagarCredenciais() }
        }
        .onAppear { clientID = Cofre.ler(.pluggyClientID) ?? "" }
    }

    private func passo(_ n: Int, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.caption.weight(.bold)).foregroundStyle(Tema.sobreAcento)
                .frame(width: 20, height: 20).background(Tema.acento, in: Circle())
            Text(texto).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Importar extrato

struct ImportarExtratoView: View {
    @Environment(\.modelContext) private var contexto
    @Query private var contas: [Conta]
    @State private var contaID = ""
    @State private var escolhendo = false
    @State private var mensagem: String?
    @State private var erro: String?

    private var conta: Conta? { contas.first { $0.externalID == contaID } }
    private var tiposOFX: [UTType] {
        [UTType(filenameExtension: "ofx"), .commaSeparatedText, .plainText, .data].compactMap { $0 }
    }

    var body: some View {
        Form {
            Section {
                Picker("Importar para a conta", selection: $contaID) {
                    Text("Escolha…").tag("")
                    ForEach(contas.filter { !$0.arquivada }, id: \.externalID) { c in
                        Text("\(c.nomeExibicao)\(c.instituicao.isEmpty ? "" : " · \(c.instituicao)")").tag(c.externalID)
                    }
                }
                Button { escolhendo = true } label: { Label("Escolher arquivo…", systemImage: "doc.badge.plus") }
                    .disabled(conta == nil)
            } footer: {
                Text("Aceita OFX e CSV do extrato ou da fatura. Lançamentos já importados não são repetidos. Útil para bancos que ficaram de fora das suas conexões.")
            }
            if contas.isEmpty {
                Section { Text("Crie uma conta primeiro em Contas e cartões (botão +).").font(.footnote).foregroundStyle(.secondary) }
            }
            if let m = mensagem { Section { Label(m, systemImage: "checkmark.circle.fill").foregroundStyle(Tema.acento) } }
            if let e = erro { Section { Label(e, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.vermelho) } }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Importar extrato")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .formStyle(.grouped)
        #endif
        .fileImporter(isPresented: $escolhendo, allowedContentTypes: tiposOFX) { resultado in
            importar(resultado)
        }
    }

    private func importar(_ resultado: Result<URL, Error>) {
        mensagem = nil; erro = nil
        guard let conta else { return }
        switch resultado {
        case .failure(let e): erro = e.localizedDescription
        case .success(let url):
            let acesso = url.startAccessingSecurityScopedResource()
            defer { if acesso { url.stopAccessingSecurityScopedResource() } }
            do {
                let dados = try Data(contentsOf: url)
                let linhas = try Importador.ler(dados, cartaoPositivoEhGasto: conta.tipo.ehCartao)
                let r = try Importador.gravar(linhas, em: conta, contexto)
                mensagem = "\(r.novas) lançamentos novos\(r.repetidas > 0 ? " · \(r.repetidas) já existiam" : "")."
            } catch {
                erro = error.localizedDescription
            }
        }
    }
}

// MARK: - Apple Pay

struct ApplePayView: View {
    @Environment(\.modelContext) private var contexto
    @Query private var contas: [Conta]
    @Query private var mapas: [MapaCartao]
    @Query(sort: \Lancamento.criadoEm, order: .reverse) private var lancamentos: [Lancamento]
    @State private var resultadoTeste: String?

    private var cartoesVistos: [String] {
        var vistos: [String] = []
        for l in lancamentos where l.origem == .carteira {
            if let c = l.cartaoCarteira, !c.isEmpty, !vistos.contains(c) { vistos.append(c) }
        }
        return vistos
    }

    var body: some View {
        Form {
            Section {
                passo(1, "No iPhone, abra o app Atalhos → Automação → Nova automação → Transação.")
                passo(2, "Escolha os cartões (ou todos) e marque “Executar imediatamente”.")
                passo(3, "Adicione a ação “Registrar compra” do Perity.")
                passo(4, "Preencha: Valor = Valor da Transação · Estabelecimento = Comerciante · Cartão = Cartão ou Cartão da Carteira.")
            } header: { Text("Configurar no iPhone (uma vez)") } footer: {
                Text("Pronto: cada compra aparece no Perity em segundos, no Mac também (via iCloud). Quando o banco confirmar, o lançamento “ao vivo” é substituído pelo oficial, sem duplicar.")
            }

            Section {
                Label("Funciona para compras por aproximação e Apple Pay. Não cobre Pix, boleto nem compra online sem Apple Pay.", systemImage: "info.circle")
                    .font(.footnote)
                Label("Alguns emissores não disparam o gatilho de Transação. Teste com cada cartão; o Open Finance continua cobrindo, no ritmo de atualização da Pluggy.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
            } header: { Text("O que esperar") }

            Section("Testar agora") {
                Button {
                    do {
                        let r = try Carteira.registrar(contexto, valorTexto: "1,00", estabelecimento: "Teste Perity", cartao: "")
                        switch r {
                        case .registrado: resultadoTeste = "Funcionou: apareceu um lançamento “Teste Perity” de R$ 1,00 nos últimos lançamentos do Início. Pode apagar."
                        case .duplicado: resultadoTeste = "Já registrei um teste há instantes."
                        case .valorInvalido: resultadoTeste = "Valor inválido."
                        }
                    } catch { resultadoTeste = error.localizedDescription }
                } label: { Label("Registrar compra de teste (R$ 1,00)", systemImage: "bolt.fill") }
                if let r = resultadoTeste { Text(r).font(.caption).foregroundStyle(.secondary) }
            }

            if !cartoesVistos.isEmpty {
                Section {
                    ForEach(cartoesVistos, id: \.self) { nome in
                        Picker(nome, selection: Binding(
                            get: { mapas.first { $0.nomeCarteira == nome }?.contaID ?? "" },
                            set: { novo in definir(nome, novo) }
                        )) {
                            Text("Automático").tag("")
                            ForEach(contas.filter { $0.tipo.ehCartao }, id: \.externalID) { c in
                                Text(c.nomeExibicao).tag(c.externalID)
                            }
                        }
                    }
                } header: { Text("Cartões da Carteira") } footer: {
                    Text("Diga a qual cartão do Perity cada cartão da Carteira corresponde, se o automático errar.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fundo)
        .navigationTitle("Apple Pay")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .formStyle(.grouped)
        #endif
    }

    private func definir(_ nome: String, _ contaID: String) {
        if let m = mapas.first(where: { $0.nomeCarteira == nome }) {
            if contaID.isEmpty { contexto.delete(m) } else { m.contaID = contaID }
        } else if !contaID.isEmpty {
            contexto.insert(MapaCartao(nomeCarteira: nome, contaID: contaID))
        }
        try? contexto.save()
    }

    private func passo(_ n: Int, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.caption.weight(.bold)).foregroundStyle(Tema.sobreAcento)
                .frame(width: 20, height: 20).background(Tema.acento, in: Circle())
            Text(texto).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}
