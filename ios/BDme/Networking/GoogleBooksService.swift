import Foundation

/// Appel direct à https://www.googleapis.com/books/v1 — pas de backend nécessaire.
/// Équivalent de server/services/googlebooks.js.
enum GoogleBooksService {
    private static let base = "https://www.googleapis.com/books/v1"

    static func apiKey() -> String? {
        KeychainStore.shared.read(key: .googleBooksApiKey)
    }

    static func search(query: String, startIndex: Int) async throws -> SearchPageResult {
        var components = URLComponents(string: "\(base)/volumes")!
        var items: [URLQueryItem] = [
            .init(name: "q", value: query),
            .init(name: "maxResults", value: "40"),
            .init(name: "startIndex", value: "\(startIndex)")
        ]
        if let key = apiKey() { items.append(.init(name: "key", value: key)) }
        components.queryItems = items

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(GBVolumesResponse.self, from: data)
        return SearchPageResult(
            results: (decoded.items ?? []).map(map(item:)),
            totalItems: decoded.totalItems ?? 0
        )
    }

    static func searchByISBN(_ ean: String) async throws -> [SearchResult] {
        var components = URLComponents(string: "\(base)/volumes")!
        var items: [URLQueryItem] = [.init(name: "q", value: "isbn:\(ean)")]
        if let key = apiKey() { items.append(.init(name: "key", value: key)) }
        components.queryItems = items

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(GBVolumesResponse.self, from: data)
        return (decoded.items ?? []).map(map(item:))
    }

    static func fetchDetails(volumeId: String) async throws -> SearchResult {
        var components = URLComponents(string: "\(base)/volumes/\(volumeId)")!
        if let key = apiKey() {
            components.queryItems = [.init(name: "key", value: key)]
        }
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let item = try JSONDecoder().decode(GBVolume.self, from: data)
        return map(item: item)
    }

    private static func map(item: GBVolume) -> SearchResult {
        let info = item.volumeInfo
        let parsed = GoogleTitleParser.parse(rawTitle: info?.title ?? "", subtitle: info?.subtitle)

        let tome = parsed.tome ?? info?.subtitle.flatMap { subtitle -> Int? in
            let digits = subtitle.filter(\.isNumber)
            return digits.isEmpty ? nil : Int(digits)
        }

        let year = info?.publishedDate.flatMap { date -> Int? in
            let prefix = date.prefix(4)
            return Int(prefix)
        }

        let ean = info?.industryIdentifiers?.first(where: { $0.type == "ISBN_13" })?.identifier
            ?? info?.industryIdentifiers?.first(where: { $0.type == "ISBN_10" })?.identifier

        var cover = info?.imageLinks?.thumbnail
        cover = cover?.replacingOccurrences(of: "http://", with: "https://")

        return SearchResult(
            bdgestId: item.id,
            title: parsed.title,
            series: parsed.series,
            tome: tome,
            author: info?.authors?.first,
            illustrator: (info?.authors?.count ?? 0) > 1 ? info?.authors?[1] : nil,
            publisher: info?.publisher,
            year: year,
            genre: info?.categories?.first,
            ean: ean,
            coverURL: cover,
            synopsis: info?.description
        )
    }
}

// MARK: - Réponses Google Books API

private struct GBVolumesResponse: Codable {
    let totalItems: Int?
    let items: [GBVolume]?
}

private struct GBVolume: Codable {
    let id: String
    let volumeInfo: GBVolumeInfo?
}

private struct GBVolumeInfo: Codable {
    let title: String?
    let subtitle: String?
    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let description: String?
    let categories: [String]?
    let industryIdentifiers: [GBIdentifier]?
    let imageLinks: GBImageLinks?
}

private struct GBIdentifier: Codable {
    let type: String
    let identifier: String
}

private struct GBImageLinks: Codable {
    let thumbnail: String?
}
