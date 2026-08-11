import Foundation

/// Appel direct à https://openlibrary.org/search.json — gratuit, sans clé.
/// Équivalent de server/services/openlibrary.js.
enum OpenLibraryService {
    static func search(query: String, startIndex: Int) async throws -> SearchPageResult {
        let pageSize = 40
        let page = startIndex / pageSize + 1

        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            .init(name: "q", value: query),
            .init(name: "subject", value: "comics"),
            .init(name: "page", value: "\(page)"),
            .init(name: "limit", value: "\(pageSize)")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(OLResponse.self, from: data)

        let results = decoded.docs.map { doc -> SearchResult in
            SearchResult(
                bdgestId: doc.key,
                title: doc.title,
                series: nil,
                tome: nil,
                author: doc.authorName?.first,
                illustrator: nil,
                publisher: doc.publisher?.first,
                year: doc.firstPublishYear,
                genre: nil,
                ean: doc.isbn?.first,
                coverURL: doc.coverI.map { "https://covers.openlibrary.org/b/id/\($0)-M.jpg" },
                synopsis: nil
            )
        }
        return SearchPageResult(results: results, totalItems: decoded.numFound)
    }
}

private struct OLResponse: Codable {
    let numFound: Int
    let docs: [OLDoc]
}

private struct OLDoc: Codable {
    let key: String
    let title: String
    let authorName: [String]?
    let publisher: [String]?
    let firstPublishYear: Int?
    let isbn: [String]?
    let coverI: Int?

    enum CodingKeys: String, CodingKey {
        case key, title
        case authorName = "author_name"
        case publisher
        case firstPublishYear = "first_publish_year"
        case isbn
        case coverI = "cover_i"
    }
}
