import Foundation

/// À chaque lancement, sauvegarde l'état courant de Books/ et Wishlist/
/// dans BDme/Backups/, avec rotation sur 3 générations :
/// backup_1 (le plus récent) → backup_2 → backup_3 (le plus ancien, écrasé).
///
/// Toutes les opérations passent par NSFileCoordinator : des déplacements/
/// suppressions non coordonnés sur des fichiers iCloud peuvent entrer en
/// conflit avec la synchronisation en cours et faire naître des copies de
/// conflit (dossiers "backup_3 2", "backup_3 3"...) qui s'accumulent à
/// chaque lancement et finissent par rendre l'opération très lente, voire
/// bloquante au point de déclencher un crash watchdog.
enum BackupManager {
    static let shared = BackupManager.self

    static func rotateBackupsAtLaunch() {
        guard let backups = ICloudContainer.backupsURL,
              let books = ICloudContainer.booksURL,
              let wishlist = ICloudContainer.wishlistURL else {
            return
        }

        let slot3 = backups.appendingPathComponent("backup_3", isDirectory: true)
        let slot2 = backups.appendingPathComponent("backup_2", isDirectory: true)
        let slot1 = backups.appendingPathComponent("backup_1", isDirectory: true)

        coordinatedRemove(at: slot3)
        coordinatedMove(from: slot2, to: slot3)
        coordinatedMove(from: slot1, to: slot2)

        try? FileManager.default.createDirectory(at: slot1, withIntermediateDirectories: true)
        copyContents(of: books, into: slot1.appendingPathComponent("Books", isDirectory: true))
        copyContents(of: wishlist, into: slot1.appendingPathComponent("Wishlist", isDirectory: true))
    }

    private static func copyContents(of source: URL, into destination: URL) {
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let target = destination.appendingPathComponent(file.lastPathComponent)
            coordinatedCopy(from: file, to: target)
        }
    }

    private static func coordinatedRemove(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &error) { coordinatedURL in
            try? FileManager.default.removeItem(at: coordinatedURL)
        }
    }

    private static func coordinatedMove(from source: URL, to destination: URL) {
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        var error: NSError?
        NSFileCoordinator().coordinate(
            writingItemAt: source, options: .forMoving,
            writingItemAt: destination, options: .forReplacing,
            error: &error
        ) { coordinatedSource, coordinatedDestination in
            try? FileManager.default.moveItem(at: coordinatedSource, to: coordinatedDestination)
        }
    }

    private static func coordinatedCopy(from source: URL, to destination: URL) {
        var error: NSError?
        NSFileCoordinator().coordinate(
            readingItemAt: source, options: [],
            writingItemAt: destination, options: .forReplacing,
            error: &error
        ) { coordinatedSource, coordinatedDestination in
            try? FileManager.default.copyItem(at: coordinatedSource, to: coordinatedDestination)
        }
    }
}
