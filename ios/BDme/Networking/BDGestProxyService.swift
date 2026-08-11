import Foundation

/// Client du mini-backend VPS OVH réduit à un proxy de recherche BDGest
/// (voir server/index.js). L'authentification bedetheque.com et le scraping
/// restent côté serveur — l'app iOS ne fait qu'appeler ce proxy.
/// L'URL du proxy et un token d'accès perso sont configurés dans Réglages.
enum BDGestProxyService {
    private static var baseURL: String? {
        KeychainStore.shared.read(key: .bdgestProxyURL)
    }
    private static var token: String? {
        KeychainStore.shared.read(key: .bdgestProxyToken)
    }

    static var isConfigured: Bool { baseURL != nil }

    static func search(query: String, startIndex: Int) async throws -> SearchPageResult {
        guard let base = baseURL, var components = URLComponents(string: "\(base)/api/search") else {
            throw SearchError.network("Proxy BDGest non configuré (Réglages).")
        }
        components.queryItems = [
            .init(name: "q", value: query),
            .init(name: "startIndex", value: "\(startIndex)"),
            .init(name: "source", value: "bdgest")
        ]
        let (data, _) = try await authorizedData(from: components.url!)
        let decoded = try JSONDecoder().decode(ProxySearchResponse.self, from: data)
        return SearchPageResult(results: decoded.results.map(\.asSearchResult), totalItems: decoded.totalItems)
    }

    static func fetchDetails(bdgestId: String) async throws -> SearchResult {
        guard let base = baseURL,
              let encoded = bdgestId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(base)/api/search/album/\(encoded)") else {
            throw SearchError.network("Proxy BDGest non configuré (Réglages).")
        }
        let (data, _) = try await authorizedData(from: url)
        let decoded = try JSONDecoder().decode(ProxyAlbumDetails.self, from: data)
        return decoded.asSearchResult(bdgestId: bdgestId)
    }

    private static func authorizedData(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await URLSession.shared.data(for: request)
    }
}

private struct ProxySearchResponse: Decodable {
    let results: [ProxyAlbum]
    let totalItems: Int
}

/// bedetheque.com renvoie l'année extraite par regex côté serveur : c'est
/// une chaîne ("2020"), pas un nombre JSON. Décode indifféremment un entier
/// JSON ou une chaîne numérique.
private struct LenientYear: Decodable {
    let value: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = Int(stringValue)
        } else {
            value = nil
        }
    }
}

/// Reflète le JSON snake_case renvoyé par server/services/bdgest.js (parseResults).
private struct ProxyAlbum: Decodable {
    let bdgestId: String
    let title: String
    let series: String?
    let tome: Int?
    let author: String?
    let illustrator: String?
    let publisher: String?
    let year: LenientYear?
    let genre: String?
    let ean: String?
    let coverUrl: String?
    let synopsis: String?

    enum CodingKeys: String, CodingKey {
        case bdgestId = "bdgest_id"
        case title, series, tome, author, illustrator, publisher, year, genre, ean
        case coverUrl = "cover_url"
        case synopsis
    }

    var asSearchResult: SearchResult {
        SearchResult(
            bdgestId: bdgestId, title: title, series: series, tome: tome,
            author: author, illustrator: illustrator, publisher: publisher,
            year: year?.value, genre: genre, ean: ean, coverURL: coverUrl, synopsis: synopsis
        )
    }
}

/// Reflète le JSON snake_case renvoyé par server/services/bdgest.js (getAlbumDetails)
/// — pas d'id dans la réponse, on réutilise celui passé en paramètre de la requête.
private struct ProxyAlbumDetails: Decodable {
    let title: String?
    let series: String?
    let tome: Int?
    let author: String?
    let illustrator: String?
    let publisher: String?
    let year: LenientYear?
    let genre: String?
    let ean: String?
    let coverUrl: String?
    let synopsis: String?

    enum CodingKeys: String, CodingKey {
        case title, series, tome, author, illustrator, publisher, year, genre, ean
        case coverUrl = "cover_url"
        case synopsis
    }

    func asSearchResult(bdgestId: String) -> SearchResult {
        SearchResult(
            bdgestId: bdgestId, title: title ?? "", series: series, tome: tome,
            author: author, illustrator: illustrator, publisher: publisher,
            year: year?.value, genre: genre, ean: ean, coverURL: coverUrl, synopsis: synopsis
        )
    }
}
