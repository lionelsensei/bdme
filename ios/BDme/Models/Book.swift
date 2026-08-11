import Foundation

/// Un album de la collection. Persisté en un fichier JSON par album
/// (BDme/Books/<id>.json) pour minimiser les collisions de sync iCloud
/// entre appareils : deux appareils qui modifient des albums différents
/// n'entrent jamais en conflit.
struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    /// volumeId Google Books, ou "bdg:<url>" pour un album BDGest.
    var bdgestId: String?
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
    var readStatus: ReadStatus
    var addedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bdgestId: String? = nil,
        title: String,
        series: String? = nil,
        tome: Int? = nil,
        author: String? = nil,
        illustrator: String? = nil,
        publisher: String? = nil,
        year: Int? = nil,
        genre: String? = nil,
        ean: String? = nil,
        coverURL: String? = nil,
        synopsis: String? = nil,
        readStatus: ReadStatus = .unread,
        addedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bdgestId = bdgestId
        self.title = title
        self.series = series
        self.tome = tome
        self.author = author
        self.illustrator = illustrator
        self.publisher = publisher
        self.year = year
        self.genre = genre
        self.ean = ean
        self.coverURL = coverURL
        self.synopsis = synopsis
        self.readStatus = readStatus
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
}
