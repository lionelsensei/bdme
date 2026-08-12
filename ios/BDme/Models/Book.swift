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
    /// Collections perso auxquelles cet album appartient (0, 1 ou plusieurs).
    var collectionIds: [UUID]
    /// "bdg:<url>" de la page série BDGest, pour lister les tomes manquants.
    var seriesBdgestId: String?
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
        collectionIds: [UUID] = [],
        seriesBdgestId: String? = nil,
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
        self.collectionIds = collectionIds
        self.seriesBdgestId = seriesBdgestId
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }

    // Décodage tolérant : les albums déjà synchronisés avant l'introduction
    // des collections n'ont pas ce champ dans leur JSON.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        bdgestId = try c.decodeIfPresent(String.self, forKey: .bdgestId)
        title = try c.decode(String.self, forKey: .title)
        series = try c.decodeIfPresent(String.self, forKey: .series)
        tome = try c.decodeIfPresent(Int.self, forKey: .tome)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        illustrator = try c.decodeIfPresent(String.self, forKey: .illustrator)
        publisher = try c.decodeIfPresent(String.self, forKey: .publisher)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        genre = try c.decodeIfPresent(String.self, forKey: .genre)
        ean = try c.decodeIfPresent(String.self, forKey: .ean)
        coverURL = try c.decodeIfPresent(String.self, forKey: .coverURL)
        synopsis = try c.decodeIfPresent(String.self, forKey: .synopsis)
        readStatus = try c.decode(ReadStatus.self, forKey: .readStatus)
        collectionIds = try c.decodeIfPresent([UUID].self, forKey: .collectionIds) ?? []
        seriesBdgestId = try c.decodeIfPresent(String.self, forKey: .seriesBdgestId)
        addedAt = try c.decode(Date.self, forKey: .addedAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}
