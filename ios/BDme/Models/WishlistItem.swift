import Foundation

/// Un item de la liste de souhaits. Persisté en un fichier JSON par item
/// (BDme/Wishlist/<id>.json), même logique anti-collision que Book.
struct WishlistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var bdgestId: String?
    var title: String
    var series: String?
    var tome: Int?
    var author: String?
    var publisher: String?
    var year: Int?
    var coverURL: String?
    var addedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bdgestId: String? = nil,
        title: String,
        series: String? = nil,
        tome: Int? = nil,
        author: String? = nil,
        publisher: String? = nil,
        year: Int? = nil,
        coverURL: String? = nil,
        addedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bdgestId = bdgestId
        self.title = title
        self.series = series
        self.tome = tome
        self.author = author
        self.publisher = publisher
        self.year = year
        self.coverURL = coverURL
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
}
