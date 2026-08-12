import Foundation

/// Pré-remplit le Keychain avec les valeurs de `Secrets.swift` (gitignoré)
/// au premier lancement, sans jamais écraser une valeur déjà modifiée par
/// l'utilisateur dans Réglages.
enum SecretsBootstrap {
    static func seedKeychainIfNeeded() {
        seed(.bdgestProxyURL, Secrets.bdgestProxyURL)
        seed(.bdgestProxyURLSecondary, Secrets.bdgestProxyURLSecondary)
        seed(.bdgestProxyToken, Secrets.bdgestProxyToken)
        seed(.googleBooksApiKey, Secrets.googleBooksApiKey)
    }

    private static func seed(_ key: KeychainStore.Key, _ value: String) {
        guard !value.isEmpty else { return }
        guard KeychainStore.shared.read(key: key) == nil else { return }
        KeychainStore.shared.write(value, key: key)
    }
}
