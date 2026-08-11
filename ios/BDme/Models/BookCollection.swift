import Foundation

/// Collection perso nommée (ex: "Franco-Belge", "Comics US", "À prêter") —
/// distincte du regroupement automatique par Série. Un album peut appartenir
/// à zéro, une ou plusieurs collections. Persisté en un fichier JSON par
/// collection (BDme/Collections/<id>.json), même logique anti-collision que
/// Book et WishlistItem.
struct BookCollection: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
