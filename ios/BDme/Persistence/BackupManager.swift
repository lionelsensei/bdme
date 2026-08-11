import Foundation

/// À chaque lancement, sauvegarde l'état courant de Books/ et Wishlist/
/// dans BDme/Backups/, avec rotation sur 3 générations :
/// backup_1 (le plus récent) → backup_2 → backup_3 (le plus ancien, écrasé).
enum BackupManager {
    static let shared = BackupManager.self

    static func rotateBackupsAtLaunch() {
        guard let backups = ICloudContainer.backupsURL,
              let books = ICloudContainer.booksURL,
              let wishlist = ICloudContainer.wishlistURL else {
            return
        }
        let fm = FileManager.default

        // Décale backup_2 -> backup_3, backup_1 -> backup_2
        let slot3 = backups.appendingPathComponent("backup_3", isDirectory: true)
        let slot2 = backups.appendingPathComponent("backup_2", isDirectory: true)
        let slot1 = backups.appendingPathComponent("backup_1", isDirectory: true)

        try? fm.removeItem(at: slot3)
        if fm.fileExists(atPath: slot2.path) {
            try? fm.moveItem(at: slot2, to: slot3)
        }
        if fm.fileExists(atPath: slot1.path) {
            try? fm.moveItem(at: slot1, to: slot2)
        }

        // Nouvelle sauvegarde de l'état courant dans backup_1
        try? fm.createDirectory(at: slot1, withIntermediateDirectories: true)
        copyContents(of: books, into: slot1.appendingPathComponent("Books", isDirectory: true))
        copyContents(of: wishlist, into: slot1.appendingPathComponent("Wishlist", isDirectory: true))
    }

    private static func copyContents(of source: URL, into destination: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        guard let files = try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let target = destination.appendingPathComponent(file.lastPathComponent)
            try? fm.copyItem(at: file, to: target)
        }
    }
}
