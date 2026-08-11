import Foundation

/// Résultat de recherche générique, quelle que soit la source.
struct SearchResult: Identifiable, Equatable {
    var id: String { bdgestId }
    let bdgestId: String
    var title: String
    var series: String?
    var tome: Int?
    var author: String?
    var illustrator: String?
    var publisher: String?
    var year: Int?
    var genre: String?
    var ean: String?
    var coverURL: String?
    var synopsis: String?
}

struct SearchPageResult {
    var results: [SearchResult]
    var totalItems: Int
}

enum SearchSource: String, CaseIterable, Identifiable {
    case googlebooks
    case openlibrary
    case bdgest
    case amazon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .googlebooks: return "Google Books"
        case .openlibrary: return "Open Library"
        case .bdgest: return "BDGest"
        case .amazon: return "Amazon"
        }
    }
}

enum SearchError: LocalizedError {
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .network(let message): return message
        case .decoding: return "Réponse invalide."
        }
    }
}

/// Reproduit server/services/googlebooks.js#parseGoogleTitle.
enum GoogleTitleParser {
    static func parse(rawTitle: String, subtitle: String?) -> (series: String?, title: String, tome: Int?) {
        // "Série - Titre - n°N"
        if let match = rawTitle.range(of: #"^(.+?) - (.+?) - n°(\d+)$"#, options: .regularExpression) {
            let groups = captureGroups(pattern: #"^(.+?) - (.+?) - n°(\d+)$"#, in: String(rawTitle[match]))
            if groups.count == 3, let tome = Int(groups[2]) {
                return (groups[0], groups[1], tome)
            }
        }
        // "Série - Titre T.N"
        if let match = rawTitle.range(of: #"^(.+?) - (.+?) T\.(\d+)$"#, options: .regularExpression) {
            let groups = captureGroups(pattern: #"^(.+?) - (.+?) T\.(\d+)$"#, in: String(rawTitle[match]))
            if groups.count == 3, let tome = Int(groups[2]) {
                return (groups[0], groups[1], tome)
            }
        }
        // "Série - Titre" (sans tome)
        if let match = rawTitle.range(of: #"^(.+?) - (.+)$"#, options: .regularExpression) {
            let groups = captureGroups(pattern: #"^(.+?) - (.+)$"#, in: String(rawTitle[match]))
            if groups.count == 2 {
                return (groups[0], groups[1], nil)
            }
        }
        // Titre seul
        return (subtitle, rawTitle, nil)
    }

    private static func captureGroups(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return [] }
        var groups: [String] = []
        for i in 1..<match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                groups.append(String(text[r]))
            }
        }
        return groups
    }
}
