import Foundation

/// Réessaie une opération réseau avec backoff exponentiel — un échec ponctuel
/// (timeout, session serveur expirée, anti-bot temporaire de bedetheque.com)
/// ne doit pas se traduire par une fiche vide sans deuxième chance.
func withRetry<T>(
    attempts: Int = 3,
    initialDelay: TimeInterval = 0.8,
    _ operation: () async throws -> T
) async throws -> T {
    var currentDelay = initialDelay
    for attempt in 1...attempts {
        do {
            return try await operation()
        } catch {
            if attempt == attempts { throw error }
            try? await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
            currentDelay *= 2
        }
    }
    fatalError("unreachable")
}

/// Sérialise les appels sortants vers le proxy BDGest avec un léger délai
/// minimum entre chaque requête : plusieurs enrichissements lancés en
/// parallèle (ajouts rapprochés) envoyaient auparavant des requêtes
/// simultanées vers bedetheque.com, augmentant le risque de blocage
/// anti-bot temporaire.
actor BDGestRequestQueue {
    static let shared = BDGestRequestQueue()

    private var lastRequestDate: Date = .distantPast
    private let minInterval: TimeInterval = 0.7

    func run<T>(_ operation: () async throws -> T) async throws -> T {
        let elapsed = Date().timeIntervalSince(lastRequestDate)
        if elapsed < minInterval {
            try? await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
        }
        lastRequestDate = Date()
        return try await operation()
    }
}
