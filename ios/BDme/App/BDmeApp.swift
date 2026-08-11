import SwiftUI

@main
struct BDmeApp: App {
    @StateObject private var library = LibraryStore()

    init() {
        BackupManager.shared.rotateBackupsAtLaunch()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .preferredColorScheme(.dark)
                .task {
                    await library.load()
                }
        }
    }
}
