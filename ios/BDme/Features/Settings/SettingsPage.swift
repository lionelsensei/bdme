import SwiftUI

/// Remplace AdminPage : plus de multi-utilisateur, juste des réglages
/// personnels stockés en Keychain (clé Google Books, proxy BDGest).
struct SettingsPage: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var googleBooksKey = KeychainStore.shared.read(key: .googleBooksApiKey) ?? ""
    @State private var bdgestProxyURL = KeychainStore.shared.read(key: .bdgestProxyURL) ?? ""
    @State private var bdgestProxyToken = KeychainStore.shared.read(key: .bdgestProxyToken) ?? ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Stockage") {
                    HStack {
                        Text("iCloud Drive")
                        Spacer()
                        Text(library.iCloudAvailable ? "Connecté" : "Indisponible")
                            .foregroundColor(library.iCloudAvailable ? BDTheme.green : BDTheme.red)
                    }
                    Text("La collection est stockée dans le dossier « BDme » à la racine d'iCloud Drive. Une sauvegarde est créée à chaque ouverture (3 versions conservées).")
                        .font(BDTheme.sans(12.5))
                        .foregroundColor(BDTheme.text3)
                }

                Section("Google Books (optionnel)") {
                    SecureField("Clé API", text: $googleBooksKey)
                    Text("Sans clé, la recherche fonctionne avec un quota limité.")
                        .font(BDTheme.sans(12)).foregroundColor(BDTheme.text3)
                }

                Section("Proxy de recherche BDGest") {
                    TextField("URL du serveur (https://…)", text: $bdgestProxyURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    SecureField("Jeton d'accès", text: $bdgestProxyToken)
                    Text("Le scraping bedetheque.com et les identifiants BDGest restent hébergés côté serveur — l'app n'appelle que ce proxy.")
                        .font(BDTheme.sans(12)).foregroundColor(BDTheme.text3)
                }

                Button("Enregistrer") {
                    KeychainStore.shared.write(googleBooksKey, key: .googleBooksApiKey)
                    KeychainStore.shared.write(bdgestProxyURL, key: .bdgestProxyURL)
                    KeychainStore.shared.write(bdgestProxyToken, key: .bdgestProxyToken)
                    saved = true
                }
                if saved {
                    Text("Enregistré.").font(BDTheme.sans(12)).foregroundColor(BDTheme.green)
                }
            }
            .navigationTitle("Réglages")
        }
    }
}
