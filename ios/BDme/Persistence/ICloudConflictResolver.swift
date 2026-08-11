import Foundation

/// Résolution basique des conflits iCloud (édition quasi-simultanée du même
/// album sur deux appareils). Stratégie : on garde la version dont la
/// modification est la plus récente et on supprime les autres versions
/// conflictuelles. Suffisant pour un usage personnel à 2 appareils —
/// pas de vrai merge de champs.
enum ICloudConflictResolver {
    static func resolvePendingConflicts(in folder: URL?) {
        guard let folder else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            guard NSFileVersion.currentVersionOfItem(at: file) != nil else { continue }
            let conflictVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: file) ?? []
            guard !conflictVersions.isEmpty else { continue }

            let allVersions = conflictVersions + [NSFileVersion.currentVersionOfItem(at: file)].compactMap { $0 }
            guard let winner = allVersions.max(by: { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) }) else {
                continue
            }

            for version in conflictVersions where version != winner {
                try? version.remove()
            }
            if winner != NSFileVersion.currentVersionOfItem(at: file) {
                try? winner.replaceItem(at: file, options: [])
            }
            try? NSFileVersion.removeOtherVersionsOfItem(at: file)
        }
    }
}
