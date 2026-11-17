import Foundation

/// Identidade desta instalação: o serviço do Keychain e o grupo de app (onde o app e os widgets trocam dados).
/// Os valores vêm do Info.plist, preenchido pelo `project.yml` a partir do arquivo `Prumo/Configuracao.local`
/// (veja `Scripts/configurar.sh`). Assim ninguém precisa editar código para usar o próprio identificador.
/// Fora de um app (testes do pacote) vale o padrão abaixo.
public enum Identidade {
    public static let servicoCofrePadrao = "com.exemplo.prumo"
    public static let grupoAppPadrao = "group.com.exemplo.prumo"

    public static var servicoCofre: String { valor("PerityServicoCofre", padrao: servicoCofrePadrao) }
    public static var grupoApp: String { valor("PerityGrupoApp", padrao: grupoAppPadrao) }

    private static func valor(_ chave: String, padrao: String) -> String {
        guard let texto = Bundle.main.object(forInfoDictionaryKey: chave) as? String else { return padrao }
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        // Variável do projeto que não foi preenchida ("$(...)" ou "${...}") não vale.
        if limpo.isEmpty || limpo.contains("$(") || limpo.contains("${") { return padrao }
        return limpo
    }
}
