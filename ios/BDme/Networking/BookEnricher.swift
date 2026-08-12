import Foundation

/// Centralise l'enrichissement d'un album via sa source d'origine (BDGest ou
/// Google Books) : la recherche en liste ne renvoie pas auteur/dessinateur/
/// résumé (trop coûteux à scraper pour chaque résultat), seule la fiche
/// détaillée par album les fournit. Utilisé à la fois juste après l'ajout
/// (proactif) et à l'ouverture du détail / bouton "Rafraîchir" (filet de
/// sécurité, idempotent).
enum BookEnricher {
    enum Skip: Error { case nothingToDo }

    /// Version "throwing" : propage l'erreur réseau pour que l'appelant
    /// puisse l'afficher (ex: LibraryStore.lastError, bouton Rafraîchir).
    static func enrich(_ book: Book) async throws -> Book {
        guard let bdgestId = book.bdgestId,
              book.author == nil || book.synopsis == nil else {
            throw Skip.nothingToDo
        }

        let details: SearchResult
        if bdgestId.hasPrefix("bdg:") {
            details = try await BDGestProxyService.fetchDetails(bdgestId: bdgestId)
        } else {
            details = try await GoogleBooksService.fetchDetails(volumeId: bdgestId)
        }

        var enriched = book
        enriched.author = book.author ?? details.author
        enriched.illustrator = book.illustrator ?? details.illustrator
        enriched.publisher = book.publisher ?? details.publisher
        enriched.genre = book.genre ?? details.genre
        enriched.synopsis = book.synopsis ?? details.synopsis
        enriched.ean = book.ean ?? details.ean
        enriched.coverURL = book.coverURL ?? details.coverURL
        enriched.seriesBdgestId = book.seriesBdgestId ?? details.seriesBdgestId
        return enriched
    }

    /// Version silencieuse (best-effort) : nil si rien à faire ou en cas d'échec.
    static func enrichIfNeeded(_ book: Book) async -> Book? {
        try? await enrich(book)
    }
}
