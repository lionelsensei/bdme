import SwiftUI

@main
struct BDmeApp: App {
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .preferredColorScheme(.dark)
                .task {
                    // Hors de init() : le travail synchrone (Keychain, iCloud)
                    // avant le premier affichage risque un crash "watchdog
                    // timeout" si le système juge le lancement trop lent.
                    SecretsBootstrap.seedKeychainIfNeeded()
                    BackupManager.shared.rotateBackupsAtLaunch()
                    await library.load()
                }
        }
    }
}
