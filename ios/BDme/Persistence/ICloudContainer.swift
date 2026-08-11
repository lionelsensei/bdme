import Foundation

/// Résout le dossier BDme dans le conteneur iCloud Drive de l'app.
/// Le conteneur `iCloud.com.lionelarbey.bdme/Documents` apparaît dans
/// l'app Fichiers comme un dossier "BDme" à la racine d'iCloud Drive.
enum ICloudContainer {
    static let identifier = "iCloud.com.lionelarbey.bdme"

    /// nil tant qu'iCloud n'est pas disponible (compte non connecté, etc.)
    static func documentsURL() -> URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: identifier) else {
            return nil
        }
        let docs = base.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs
    }

    static func subfolder(_ name: String) -> URL? {
        guard let docs = documentsURL() else { return nil }
        let url = docs.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var booksURL: URL? { subfolder("Books") }
    static var wishlistURL: URL? { subfolder("Wishlist") }
    static var collectionsURL: URL? { subfolder("Collections") }
    static var backupsURL: URL? { subfolder("Backups") }

    /// Repli local (hors iCloud) utilisé si le compte iCloud n'est pas disponible,
    /// pour que l'app reste fonctionnelle sans jamais perdre de données.
    static func localFallbackDocumentsURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
    }
}
