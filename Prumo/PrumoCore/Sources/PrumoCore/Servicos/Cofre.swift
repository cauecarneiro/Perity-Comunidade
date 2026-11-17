import Foundation
import Security

/// Guarda segredos (Client Secret da Pluggy) no Keychain do aparelho. Nunca em arquivo, nunca no iCloud.
public enum Cofre {
    public static var servico: String { Identidade.servicoCofre }

    public enum Chave: String {
        case pluggyClientID = "pluggy.clientId"
        case pluggyClientSecret = "pluggy.clientSecret"
    }

    /// `moderno`: Keychain protegido por dados (exige app assinado com entitlement). Fora disso, no macOS,
    /// cai para o Keychain tradicional, para builds de desenvolvimento sem assinatura.
    private static func consulta(_ chave: String, moderno: Bool) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: chave,
        ]
        #if os(macOS)
        if moderno { q[kSecUseDataProtectionKeychain as String] = true }
        #endif
        return q
    }

    private static var modos: [Bool] {
        #if os(macOS)
        return [true, false]
        #else
        return [true]
        #endif
    }

    /// Só em desenvolvimento: durante a captura de telas o Keychain não é tocado (nem para ler).
    private static var emCaptura: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "prumo-captura") != nil
        #else
        return false
        #endif
    }

    @discardableResult
    public static func salvar(_ valor: String, para chave: Chave) -> Bool {
        if emCaptura { return false }
        let dados = Data(valor.utf8)
        for moderno in modos {
            var q = consulta(chave.rawValue, moderno: moderno)
            SecItemDelete(q as CFDictionary)
            q[kSecValueData as String] = dados
            // Somente neste aparelho, só quando desbloqueado.
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            if SecItemAdd(q as CFDictionary, nil) == errSecSuccess { return true }
        }
        return false
    }

    public static func ler(_ chave: Chave) -> String? {
        if emCaptura { return nil }
        for moderno in modos {
            var q = consulta(chave.rawValue, moderno: moderno)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var resultado: AnyObject?
            if SecItemCopyMatching(q as CFDictionary, &resultado) == errSecSuccess,
               let dados = resultado as? Data,
               let texto = String(data: dados, encoding: .utf8) { return texto }
        }
        return nil
    }

    public static func apagar(_ chave: Chave) {
        for moderno in modos { SecItemDelete(consulta(chave.rawValue, moderno: moderno) as CFDictionary) }
    }

    public static func credenciaisPluggy() -> PluggyCredenciais? {
        guard let id = ler(.pluggyClientID), let segredo = ler(.pluggyClientSecret) else { return nil }
        let c = PluggyCredenciais(clientID: id, clientSecret: segredo)
        return c.estaCompleta ? c : nil
    }
}

/// Preferências deste aparelho (não sincronizam: cada aparelho decide por si).
public enum Preferencias {
    private static let d = UserDefaults.standard

    public enum Chave {
        static let buscaBancos = "prumo.dispositivoBuscaBancos"
        static let modoDemo = "prumo.modoDemo"
        static let ultimaSync = "prumo.ultimaSincronizacao"
        static let intervaloMinutos = "prumo.intervaloSyncMinutos"
        static let ocultarValores = "prumo.ocultarValores"
        static let versaoCategorias = "prumo.versaoCategorias"
    }

    /// Só um aparelho (normalmente o Mac) deve buscar na Pluggy; os demais recebem pelo iCloud.
    public static var dispositivoBuscaBancos: Bool {
        get { d.bool(forKey: Chave.buscaBancos) }
        set { d.set(newValue, forKey: Chave.buscaBancos) }
    }

    public static var modoDemo: Bool {
        get { d.object(forKey: Chave.modoDemo) as? Bool ?? false }
        set { d.set(newValue, forKey: Chave.modoDemo) }
    }

    /// Ocultar valores do Início (é o que o widget segue).
    public static var ocultarValores: Bool {
        get { d.bool(forKey: Chave.ocultarValores) }
        set { d.set(newValue, forKey: Chave.ocultarValores) }
    }

    /// Ocultar valores de uma página ("inicio", "investimentos", "fixos"). "inicio" usa a chave antiga.
    public static func ocultarValores(pagina: String) -> Bool {
        pagina == "inicio" ? ocultarValores : d.bool(forKey: Chave.ocultarValores + "." + pagina)
    }

    public static func definirOcultarValores(_ oculto: Bool, pagina: String) {
        if pagina == "inicio" { ocultarValores = oculto } else { d.set(oculto, forKey: Chave.ocultarValores + "." + pagina) }
    }

    /// Última versão da lista de categorias já aplicada aos lançamentos deste aparelho (ver `Recategorizador`).
    public static var versaoCategorias: Int {
        get { d.integer(forKey: Chave.versaoCategorias) }
        set { d.set(newValue, forKey: Chave.versaoCategorias) }
    }

    public static var ultimaSincronizacao: Date? {
        get { d.object(forKey: Chave.ultimaSync) as? Date }
        set { d.set(newValue, forKey: Chave.ultimaSync) }
    }

    public static var intervaloSyncMinutos: Int {
        get { let v = d.integer(forKey: Chave.intervaloMinutos); return v > 0 ? v : 60 }
        set { d.set(newValue, forKey: Chave.intervaloMinutos) }
    }
}
