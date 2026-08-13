import Foundation

/// Client du mini-backend VPS OVH réduit à un proxy de recherche BDGest
/// (voir server/index.js). L'authentification bedetheque.com et le scraping
/// restent côté serveur — l'app iOS ne fait qu'appeler ce proxy.
/// L'URL du proxy et un token d'accès perso sont configurés dans Réglages.
/// Les appels passent par BDGestRequestQueue (sérialisation + délai minimum)
/// et withRetry (backoff) pour limiter le risque de blocage anti-bot côté
/// bedetheque.com quand plusieurs enrichissements sont lancés en rafale.
enum BDGestProxyService {
    /// `bdgestId`/`seriesBdgestId` sont des URL Bedetheque complètes
    /// (`bdg:https://…/…`) insérées comme UN SEUL segment de chemin
    /// (`/api/search/album/:id`). `.urlPathAllowed` laisse passer `/` et
    /// `:` tels quels, ce qui casse le matching de la route côté serveur
    /// (elle voit alors plusieurs segments) sans qu'aucune requête
    /// n'atteigne le serveur — d'où un échec silencieux. On encode donc
    /// tout sauf les caractères non réservés RFC 3986 pour obtenir un
    /// segment opaque (`%2F`, `%3A`, …), déjà décodé correctement côté
    /// serveur (voir aussi `AllowEncodedSlashes NoDecode` sur VPS2).
    private static let pathSegmentAllowed = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static var baseURL: String? {
        KeychainStore.shared.read(key: .bdgestProxyURL)
    }
    private static var secondaryBaseURL: String? {
        KeychainStore.shared.read(key: .bdgestProxyURLSecondary)
    }
    private static var token: String? {
        KeychainStore.shared.read(key: .bdgestProxyToken)
    }

    static var isConfigured: Bool { baseURL != nil }

    /// URL principale, puis URL de repli si configurée — essayées dans
    /// l'ordre. Un VPS bloqué (anti-bot) ne rend pas la recherche
    /// indisponible si l'autre répond.
    private static func candidateBaseURLs() -> [String] {
        [baseURL, secondaryBaseURL].compactMap { $0 }.filter { !$0.isEmpty }
    }

    static func search(query: String, startIndex: Int) async throws -> SearchPageResult {
        let cacheKey = "bdgest|\(query.lowercased())|\(startIndex)"
        let bases = candidateBaseURLs()
        guard !bases.isEmpty else {
            throw SearchError.network("Proxy BDGest non configuré (Réglages).")
        }

        var lastError: Error = SearchError.network("Proxy BDGest non configuré (Réglages).")
        for base in bases {
            guard var components = URLComponents(string: "\(base)/api/search") else { continue }
            components.queryItems = [
                .init(name: "q", value: query),
                .init(name: "startIndex", value: "\(startIndex)"),
                .init(name: "source", value: "bdgest")
            ]
            guard let url = components.url else { continue }
            do {
                let page = try await BDGestRequestQueue.shared.run {
                    try await withRetry {
                        let (data, _) = try await authorizedData(from: url)
                        let decoded = try JSONDecoder().decode(ProxySearchResponse.self, from: data)
                        return SearchPageResult(results: decoded.results.map(\.asSearchResult), totalItems: decoded.totalItems)
                    }
                }
                await OfflineCache.searchResults.set(page.results, for: cacheKey)
                return page
            } catch {
                lastError = error
            }
        }
        if let cached = await OfflineCache.searchResults.get(cacheKey) {
            return SearchPageResult(results: cached, totalItems: cached.count)
        }
        throw lastError
    }

    static func fetchDetails(bdgestId: String) async throws -> SearchResult {
        let bases = candidateBaseURLs()
        guard !bases.isEmpty else {
            throw SearchError.network("Proxy BDGest non configuré (Réglages).")
        }

        var lastError: Error = SearchError.network("Proxy BDGest non configuré (Réglages).")
        for base in bases {
            guard let encoded = bdgestId.addingPercentEncoding(withAllowedCharacters: pathSegmentAllowed),
                  let url = URL(string: "\(base)/api/search/album/\(encoded)") else { continue }
            do {
                let result = try await BDGestRequestQueue.shared.run {
                    try await withRetry {
                        let (data, _) = try await authorizedData(from: url)
                        let decoded = try JSONDecoder().decode(ProxyAlbumDetails.self, from: data)
                        return decoded.asSearchResult(bdgestId: bdgestId)
                    }
                }
                await OfflineCache.albumDetails.set(result, for: bdgestId)
                return result
            } catch {
                lastError = error
            }
        }
        if let cached = await OfflineCache.albumDetails.get(bdgestId) {
            return cached
        }
        throw lastError
    }

    /// Liste tous les tomes d'une série (pour détecter ceux qui manquent).
    static func fetchSeriesTomes(seriesBdgestId: String) async throws -> [SeriesTome] {
        let bases = candidateBaseURLs()
        guard !bases.isEmpty else {
            throw SearchError.network("Proxy BDGest non configuré (Réglages).")
        }

        var lastError: Error = SearchError.network("Proxy BDGest non configuré (Réglages).")
        for base in bases {
            guard let encoded = seriesBdgestId.addingPercentEncoding(withAllowedCharacters: pathSegmentAllowed),
                  let url = URL(string: "\(base)/api/search/series/\(encoded)") else { continue }
            do {
                let tomes = try await BDGestRequestQueue.shared.run {
                    try await withRetry {
                        let (data, _) = try await authorizedData(from: url)
                        let decoded = try JSONDecoder().decode(ProxySeriesResponse.self, from: data)
                        return decoded.tomes.map(\.asSeriesTome)
                    }
                }
                await OfflineCache.seriesTomes.set(tomes, for: seriesBdgestId)
                return tomes
            } catch {
                lastError = error
            }
        }
        if let cached = await OfflineCache.seriesTomes.get(seriesBdgestId) {
            return cached
        }
        throw lastError
    }

    private static func authorizedData(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        // Le serveur répond {"error": "..."} avec un statut 4xx/5xx en cas
        // d'échec (identifiants, circuit breaker, Bedetheque indisponible…).
        // Sans ce contrôle, JSONDecoder échoue en tentant de décoder cette
        // erreur comme la réponse attendue et masque le vrai message
        // derrière "The data couldn't be read...".
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(ProxyErrorResponse.self, from: data))?.error
            throw SearchError.network(message ?? "Erreur serveur (\(http.statusCode)).")
        }
        return (data, response)
    }
}

private struct ProxyErrorResponse: Decodable {
    let error: String
}

/// Un tome référencé sur la page série BDGest.
struct SeriesTome: Identifiable, Equatable, Codable {
    var id: String { bdgestId }
    let bdgestId: String
    let tome: Int?
    let title: String?
    let coverURL: String?
}

private struct ProxySearchResponse: Decodable {
    let results: [ProxyAlbum]
    let totalItems: Int
}

private struct ProxySeriesResponse: Decodable {
    let tomes: [ProxySeriesTome]
}

private struct ProxySeriesTome: Decodable {
    let bdgestId: String
    let tome: Int?
    let title: String?
    let coverUrl: String?

    enum CodingKeys: String, CodingKey {
        case bdgestId = "bdgest_id"
        case tome, title
        case coverUrl = "cover_url"
    }

    var asSeriesTome: SeriesTome {
        SeriesTome(bdgestId: bdgestId, tome: tome, title: title, coverURL: coverUrl)
    }
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
    let isSeries: Bool?

    enum CodingKeys: String, CodingKey {
        case bdgestId = "bdgest_id"
        case title, series, tome, author, illustrator, publisher, year, genre, ean
        case coverUrl = "cover_url"
        case synopsis
        case isSeries = "is_series"
    }

    var asSearchResult: SearchResult {
        SearchResult(
            bdgestId: bdgestId, title: title, series: series, tome: tome,
            author: author, illustrator: illustrator, publisher: publisher,
            year: year?.value, genre: genre, ean: ean, coverURL: coverUrl, synopsis: synopsis,
            // Le résultat EST la série : on réutilise son bdgestId (déjà "bdg:<url série>")
            // pour lister les tomes ensuite.
            seriesBdgestId: (isSeries ?? false) ? bdgestId : nil,
            isSeries: isSeries ?? false
        )
    }
}

/// Reflète le JSON renvoyé par server/services/bdgest.js (getAlbumDetails) —
/// pas d'id dans la réponse, on réutilise celui passé en paramètre de la
/// requête. `seriesUrl` est en camelCase côté serveur (contrairement à
/// `cover_url`, historiquement en snake_case).
private struct ProxyAlbumDetails: Decodable {
    let title: String?
    let series: String?
    let seriesUrl: String?
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
        case title, series, seriesUrl, tome, author, illustrator, publisher, year, genre, ean
        case coverUrl = "cover_url"
        case synopsis
    }

    func asSearchResult(bdgestId: String) -> SearchResult {
        SearchResult(
            bdgestId: bdgestId, title: title ?? "", series: series, tome: tome,
            author: author, illustrator: illustrator, publisher: publisher,
            year: year?.value, genre: genre, ean: ean, coverURL: coverUrl, synopsis: synopsis,
            seriesBdgestId: seriesUrl.map { "bdg:\($0)" }
        )
    }
}
