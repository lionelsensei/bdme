import SwiftUI

/// Remplace AdminPage : plus de multi-utilisateur, juste des réglages
/// personnels stockés en Keychain (clé Google Books, proxy BDGest).
struct SettingsPage: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var googleBooksKey = KeychainStore.shared.read(key: .googleBooksApiKey) ?? ""
    @State private var bdgestProxyURL = KeychainStore.shared.read(key: .bdgestProxyURL) ?? "https://bdme.liooonel.fr"
    @State private var bdgestProxyURLSecondary = KeychainStore.shared.read(key: .bdgestProxyURLSecondary) ?? "https://bdme2.liooonel.fr"
    @State private var bdgestProxyToken = KeychainStore.shared.read(key: .bdgestProxyToken) ?? ""
    @State private var saved = false
    @State private var cacheEntryCount: (albums: Int, searches: Int, series: Int)?

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
                    TextField("URL principale (https://…)", text: $bdgestProxyURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    TextField("URL de repli (optionnel)", text: $bdgestProxyURLSecondary)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    SecureField("Jeton d'accès", text: $bdgestProxyToken)
                    Text("Si l'URL principale échoue (blocage anti-bot temporaire), l'app essaie automatiquement l'URL de repli avant d'abandonner. Le scraping bedetheque.com et les identifiants BDGest restent hébergés côté serveur — l'app n'appelle que ces proxys.")
                        .font(BDTheme.sans(12)).foregroundColor(BDTheme.text3)
                }

                Button("Enregistrer") {
                    KeychainStore.shared.write(googleBooksKey, key: .googleBooksApiKey)
                    KeychainStore.shared.write(bdgestProxyURL, key: .bdgestProxyURL)
                    KeychainStore.shared.write(bdgestProxyURLSecondary, key: .bdgestProxyURLSecondary)
                    KeychainStore.shared.write(bdgestProxyToken, key: .bdgestProxyToken)
                    saved = true
                }
                if saved {
                    Text("Enregistré.").font(BDTheme.sans(12)).foregroundColor(BDTheme.green)
                }

                Section("Cache hors-ligne") {
                    if let cacheEntryCount {
                        Text("\(cacheEntryCount.albums) fiches album · \(cacheEntryCount.searches) recherches · \(cacheEntryCount.series) séries en cache local")
                            .font(BDTheme.sans(12.5)).foregroundColor(BDTheme.text3)
                    } else {
                        Text("Chargement…").font(BDTheme.sans(12.5)).foregroundColor(BDTheme.text3)
                    }
                    Text("Chaque recherche et fiche déjà consultée reste disponible hors connexion.")
                        .font(BDTheme.sans(12)).foregroundColor(BDTheme.text3)
                    Button("Vider le cache") {
                        Task {
                            await OfflineCache.albumDetails.clear()
                            await OfflineCache.searchResults.clear()
                            await OfflineCache.seriesTomes.clear()
                            await loadCacheStats()
                        }
                    }
                    .foregroundColor(BDTheme.red)
                }

                if !library.recentErrors.isEmpty {
                    Section("Erreurs récentes") {
                        ForEach(library.recentErrors.indices, id: \.self) { idx in
                            let entry = library.recentErrors[idx]
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.message).font(BDTheme.sans(12)).foregroundColor(BDTheme.text2)
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(BDTheme.sans(10.5)).foregroundColor(BDTheme.text3)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppVersion.display)
                            .foregroundColor(BDTheme.text3)
                    }
                }
            }
            .navigationTitle("Réglages")
            .task { await loadCacheStats() }
        }
    }

    private func loadCacheStats() async {
        cacheEntryCount = (
            albums: await OfflineCache.albumDetails.count(),
            searches: await OfflineCache.searchResults.count(),
            series: await OfflineCache.seriesTomes.count()
        )
    }
}

enum AppVersion {
    static var display: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }
}
