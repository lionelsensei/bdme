import Foundation

enum ReadStatus: String, Codable, CaseIterable {
    case unread
    case reading
    case read

    var label: String {
        switch self {
        case .unread: return "Non lu"
        case .reading: return "En cours"
        case .read: return "Lu"
        }
    }
}
