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
        let decoded = try JSONDecoder().decode(ProxyAlbum.self, from: data)
        return decoded.asSearchResult
    }

    private static func authorizedData(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await URLSession.shared.data(for: request)
    }
}

private struct ProxySearchResponse: Codable {
    let results: [ProxyAlbum]
    let totalItems: Int
}

private struct ProxyAlbum: Codable {
    let bdgestId: String
    let title: String
    let series: String?
    let tome: Int?
    let author: String?
    let illustrator: String?
    let publisher: String?
    let year: Int?
    let genre: String?
    let ean: String?
    let coverUrl: String?
    let synopsis: String?

    var asSearchResult: SearchResult {
        SearchResult(
            bdgestId: bdgestId, title: title, series: series, tome: tome,
            author: author, illustrator: illustrator, publisher: publisher,
            year: year, genre: genre, ean: ean, coverURL: coverUrl, synopsis: synopsis
        )
    }
}
