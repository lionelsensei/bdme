import SwiftUI
import CryptoKit

/// Remplaçant de `AsyncImage` avec cache disque persistant (dossier
/// `Caches/`, hors iCloud) : chaque couverture n'est téléchargée qu'une
/// fois, puis réutilisée à chaque affichage sans repasser par le réseau.
/// Même API par phase qu'AsyncImage — les appels existants n'ont besoin
/// que de renommer `AsyncImage` en `CachedAsyncImage`.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) {
                await load()
            }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }
        if let uiImage = await CoverImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: uiImage))
        } else {
            phase = .failure(CocoaError(.fileReadUnknown))
        }
    }
}

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure(Error)
}

/// Cache disque des couvertures, clé = hash SHA256 de l'URL (même schéma
/// que LocalCache/OfflineCache pour les données texte).
actor CoverImageCache {
    static let shared = CoverImageCache()

    private let folder: URL
    private var memoryCache: [URL: UIImage] = [:]

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        folder = caches.appendingPathComponent("BDmeOfflineCache/CoverImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = memoryCache[url] {
            return cached
        }

        let path = fileURL(for: url)
        if let data = try? Data(contentsOf: path), let image = UIImage(data: data) {
            memoryCache[url] = image
            return image
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return nil
        }
        try? data.write(to: path, options: .atomic)
        memoryCache[url] = image
        return image
    }

    func clear() {
        memoryCache.removeAll()
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    func count() -> Int {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).count) ?? 0
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent("\(hex).img")
    }
}

import CryptoKit
