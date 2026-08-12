import Foundation
import CryptoKit

/// Cache disque générique, hors iCloud (dossier `Caches/`, purement local à
/// l'appareil — ce sont des données dérivées, re-téléchargeables, pas des
/// données précieuses à synchroniser ou sauvegarder).
///
/// Sert de repli hors-ligne : chaque recherche/fiche réussie est mise en
/// cache ; en cas d'échec réseau, on retombe sur la dernière version connue
/// plutôt que d'échouer complètement. Alimente aussi la Phase 2 (recherche
/// instantanée sur ce qui a déjà été consulté) sans nécessiter de dump
/// complet de la base BDGest.
actor LocalCache<T: Codable> {
    private let folder: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(name: String) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        folder = caches.appendingPathComponent("BDmeOfflineCache/\(name)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func get(_ key: String) -> T? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func set(_ value: T, for key: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    /// Nombre d'entrées en cache — informatif (Réglages).
    func count() -> Int {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).count) ?? 0
    }

    func clear() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    /// Nom de fichier stable entre les lancements (String.hashValue est
    /// aléatoire par processus, donc inutilisable comme clé de cache).
    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent("\(hex).json")
    }
}

/// Instances partagées par type de donnée mise en cache.
enum OfflineCache {
    static let albumDetails = LocalCache<SearchResult>(name: "AlbumDetails")
    static let searchResults = LocalCache<[SearchResult]>(name: "SearchResults")
    static let seriesTomes = LocalCache<[SeriesTome]>(name: "SeriesTomes")
}
