import Foundation

/// Repository générique : un objet Codable == un fichier JSON dans un dossier donné.
/// Toutes les I/O passent par NSFileCoordinator pour rester correctes pendant
/// que iCloud synchronise le fichier en arrière-plan.
final class FileRepository<T: Codable & Identifiable> where T.ID == UUID {
    private let folderProvider: () -> URL?
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(folderProvider: @escaping () -> URL?) {
        self.folderProvider = folderProvider
    }

    private func folder() throws -> URL {
        guard let url = folderProvider() else {
            throw RepositoryError.iCloudUnavailable
        }
        return url
    }

    private func fileURL(for id: UUID) throws -> URL {
        try folder().appendingPathComponent("\(id.uuidString).json")
    }

    func loadAll() throws -> [T] {
        let dir = try folder()
        let files = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        var items: [T] = []
        for file in files {
            if let item = try? read(at: file) {
                items.append(item)
            }
        }
        return items
    }

    func save(_ item: T) throws {
        let url = try fileURL(for: item.id)
        let data = try encoder.encode(item)
        var coordError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordError { throw coordError }
        if let writeError { throw writeError }
    }

    func delete(id: UUID) throws {
        let url = try fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var coordError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { coordinatedURL in
            try? FileManager.default.removeItem(at: coordinatedURL)
        }
        if let coordError { throw coordError }
    }

    private func read(at url: URL) throws -> T {
        var result: Result<T, Error>!
        var coordError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordinatedURL in
            do {
                let data = try Data(contentsOf: coordinatedURL)
                result = .success(try decoder.decode(T.self, from: data))
            } catch {
                result = .failure(error)
            }
        }
        if let coordError { throw coordError }
        return try result.get()
    }
}

enum RepositoryError: LocalizedError {
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud Drive n'est pas disponible sur cet appareil."
        }
    }
}
