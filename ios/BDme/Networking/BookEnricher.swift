import Foundation

/// Centralise l'enrichissement d'un album via sa source d'origine (BDGest ou
/// Google Books) : la recherche en liste ne renvoie pas auteur/dessinateur/
/// résumé (trop coûteux à scraper pour chaque résultat), seule la fiche
/// détaillée par album les fournit. Utilisé à la fois juste après l'ajout
/// (proactif) et à l'ouverture du détail (filet de sécurité, idempotent).
enum BookEnricher {
    static func enrichIfNeeded(_ book: Book) async -> Book? {
        guard let bdgestId = book.bdgestId,
              book.author == nil || book.synopsis == nil else { return nil }

        do {
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

            guard enriched != book else { return nil }
            return enriched
        } catch {
            return nil
        }
    }
}
