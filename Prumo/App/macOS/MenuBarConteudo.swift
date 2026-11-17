import AppKit
import SwiftData
import SwiftUI
import PrumoCore

/// O que aparece ao clicar no ícone do Perity na barra de menus do Mac.
struct MenuBarConteudo: View {
    @Environment(EstadoApp.self) private var estado
    @Environment(\.openWindow) private var abrirJanela
    @Query private var lancamentos: [Lancamento]
    @Query private var contas: [Conta]

    var body: some View {
        let hoje = Date()
        let mes = Analise.resumoDoMes(hoje, lancamentos: lancamentos, contas: contas, hoje: hoje)
        let ini = Datas.inicioDoDia(hoje)
        let doDia = Analise.resumo(lancamentos: lancamentos, contas: contas, de: ini, ate: Datas.somar(dias: 1, a: ini))
        let prev = Analise.previsaoDoMes(lancamentos: lancamentos, contas: contas, hoje: hoje)
        let recentes = lancamentos
            .filter { $0.conciliadoComID == nil && !$0.ignorado && !$0.interno }
            .sorted { ($0.data, $0.criadoEm) > ($1.data, $1.criadoEm) }
            .prefix(5)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 20) {
                bloco("Hoje", doDia.despesasCentavos)
                bloco("No mês", mes.despesasCentavos)
                bloco("Previsão", prev.projetadoCentavos)
            }
            Fio()
            ForEach(Array(recentes), id: \.externalID) { l in
                HStack(spacing: 8) {
                    Text(l.titulo).lineLimit(1).font(.callout)
                    Spacer(minLength: 8)
                    Valor(centavos: l.valorCentavos, colorido: true).font(.numero(13, .medium))
                }
            }
            Fio()
            HStack {
                IndicadorAtualizacao()
                Spacer()
                if estado.buscaBancos && estado.temCredenciais && !estado.modoDemo {
                    Button("Atualizar") { Task { await estado.atualizar() } }
                }
                Button("Abrir Perity") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    NSApplication.shared.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
                }
                Button("Sair") { NSApplication.shared.terminate(nil) }
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 350)
        .background(Tema.fundo)
        .foregroundStyle(Tema.texto)
    }

    private func bloco(_ titulo: String, _ centavos: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo).rotulo()
            Valor(centavos: centavos, compacto: true).font(.numero(20))
        }
    }
}
