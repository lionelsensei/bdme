import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published private(set) var wishlist: [WishlistItem] = []
    @Published private(set) var collections: [BookCollection] = []
    @Published var iCloudAvailable: Bool = ICloudContainer.documentsURL() != nil
    @Published var lastError: String?

    private lazy var bookRepo = FileRepository<Book>(folderProvider: { ICloudContainer.booksURL })
    private lazy var wishlistRepo = FileRepository<WishlistItem>(folderProvider: { ICloudContainer.wishlistURL })
    private lazy var collectionRepo = FileRepository<BookCollection>(folderProvider: { ICloudContainer.collectionsURL })

    func load() async {
        ICloudConflictResolver.resolvePendingConflicts(in: ICloudContainer.booksURL)
        ICloudConflictResolver.resolvePendingConflicts(in: ICloudContainer.wishlistURL)
        ICloudConflictResolver.resolvePendingConflicts(in: ICloudContainer.collectionsURL)
        // Chaque source est chargée indépendamment : un échec ponctuel sur
        // l'une (latence iCloud, coordination fichier) ne doit jamais
        // vider silencieusement les autres.
        do {
            books = try bookRepo.loadAll().sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            lastError = error.localizedDescription
        }
        do {
            wishlist = try wishlistRepo.loadAll().sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            lastError = error.localizedDescription
        }
        do {
            collections = try collectionRepo.loadAll().sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Collection

    /// Ajoute l'album immédiatement (pas d'attente réseau), puis lance
    /// l'enrichissement (auteur, dessinateur, résumé…) en tâche de fond.
    func addBookEnriching(_ book: Book) {
        addBook(book)
        Task {
            if let enriched = await BookEnricher.enrichIfNeeded(book) {
                updateBook(enriched)
            }
        }
    }

    func addBook(_ book: Book) {
        do {
            try bookRepo.save(book)
            books.append(book)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateBook(_ book: Book) {
        var updated = book
        updated.updatedAt = Date()
        do {
            try bookRepo.save(updated)
            if let idx = books.firstIndex(where: { $0.id == updated.id }) {
                books[idx] = updated
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteBook(_ book: Book) {
        do {
            try bookRepo.delete(id: book.id)
            books.removeAll { $0.id == book.id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Wishlist

    func addWishlistItem(_ item: WishlistItem) {
        do {
            try wishlistRepo.save(item)
            wishlist.append(item)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteWishlistItem(_ item: WishlistItem) {
        do {
            try wishlistRepo.delete(id: item.id)
            wishlist.removeAll { $0.id == item.id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    var allSeries: [String] {
        Array(Set(books.compactMap { $0.series })).sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    // MARK: Collections perso

    @discardableResult
    func createCollection(name: String) -> BookCollection {
        let collection = BookCollection(name: name)
        do {
            try collectionRepo.save(collection)
            collections.append(collection)
            collections.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch {
            lastError = error.localizedDescription
        }
        return collection
    }

    func renameCollection(_ collection: BookCollection, to name: String) {
        var updated = collection
        updated.name = name
        updated.updatedAt = Date()
        do {
            try collectionRepo.save(updated)
            if let idx = collections.firstIndex(where: { $0.id == updated.id }) {
                collections[idx] = updated
            }
            collections.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Supprime la collection et retire sa référence de tous les albums membres.
    func deleteCollection(_ collection: BookCollection) {
        do {
            try collectionRepo.delete(id: collection.id)
            collections.removeAll { $0.id == collection.id }
            for book in books where book.collectionIds.contains(collection.id) {
                var updated = book
                updated.collectionIds.removeAll { $0 == collection.id }
                updateBook(updated)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setCollections(_ collectionIds: [UUID], for book: Book) {
        var updated = book
        updated.collectionIds = collectionIds
        updateBook(updated)
    }

    func books(in collection: BookCollection) -> [Book] {
        books.filter { $0.collectionIds.contains(collection.id) }
    }

    /// Suggère des collections pertinentes pour un résultat de recherche,
    /// en se basant sur les métadonnées : une collection contenant déjà un
    /// album de la même série est un signal fort ; à défaut, même éditeur
    /// ou même genre. Trié par pertinence décroissante.
    func suggestedCollections(for result: SearchResult) -> [BookCollection] {
        guard !collections.isEmpty else { return [] }

        var scores: [UUID: Int] = [:]
        for book in books {
            guard !book.collectionIds.isEmpty else { continue }
            var score = 0
            if let series = result.series, let bookSeries = book.series, !series.isEmpty,
               series.localizedCaseInsensitiveCompare(bookSeries) == .orderedSame {
                score += 5
            }
            if let publisher = result.publisher, let bookPublisher = book.publisher, !publisher.isEmpty,
               publisher.localizedCaseInsensitiveCompare(bookPublisher) == .orderedSame {
                score += 2
            }
            if let genre = result.genre, let bookGenre = book.genre, !genre.isEmpty,
               genre.localizedCaseInsensitiveCompare(bookGenre) == .orderedSame {
                score += 1
            }
            guard score > 0 else { continue }
            for id in book.collectionIds {
                scores[id, default: 0] += score
            }
        }

        return scores.sorted { $0.value > $1.value }
            .compactMap { pair in collections.first { $0.id == pair.key } }
    }
}
