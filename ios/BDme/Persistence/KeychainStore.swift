import Foundation
import Security

/// Stockage sécurisé des secrets perso (clé Google Books, URL du proxy BDGest).
/// Remplace bdme_api_keys côté Supabase : plus d'admin multi-utilisateur,
/// juste des réglages personnels en Keychain.
final class KeychainStore {
    static let shared = KeychainStore()

    enum Key: String {
        case googleBooksApiKey = "com.lionelarbey.bdme.googleBooksApiKey"
        case bdgestProxyURL = "com.lionelarbey.bdme.bdgestProxyURL"
        case bdgestProxyToken = "com.lionelarbey.bdme.bdgestProxyToken"
        /// URL de repli, essayée si l'URL principale échoue (ex: blocage
        /// anti-bot temporaire sur un des deux VPS).
        case bdgestProxyURLSecondary = "com.lionelarbey.bdme.bdgestProxyURLSecondary"
    }

    func read(key: Key) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String, key: Key) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func delete(key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}
