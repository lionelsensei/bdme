import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published private(set) var wishlist: [WishlistItem] = []
    @Published var iCloudAvailable: Bool = ICloudContainer.documentsURL() != nil
    @Published var lastError: String?

    private lazy var bookRepo = FileRepository<Book>(folderProvider: { ICloudContainer.booksURL })
    private lazy var wishlistRepo = FileRepository<WishlistItem>(folderProvider: { ICloudContainer.wishlistURL })

    func load() async {
        ICloudConflictResolver.resolvePendingConflicts(in: ICloudContainer.booksURL)
        ICloudConflictResolver.resolvePendingConflicts(in: ICloudContainer.wishlistURL)
        do {
            books = try bookRepo.loadAll().sorted { $0.updatedAt > $1.updatedAt }
            wishlist = try wishlistRepo.loadAll().sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Collection

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
}
