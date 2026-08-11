import SwiftUI
import VisionKit

/// Équivalent de ScanButton.jsx : scan EAN caméra ou saisie manuelle,
/// recherche l'album correspondant et propose ajout collection/wishlist.
struct ScanSheet: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .camera
    @State private var manualEAN = ""
    @State private var found: SearchResult?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var pickingCollectionFor: SearchResult?

    enum Mode { case camera, manual }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    Text("Caméra").tag(Mode.camera)
                    Text("Manuel").tag(Mode.manual)
                }
                .pickerStyle(.segmented)

                if mode == .camera {
                    if #available(iOS 16.0, *), DataScannerAvailability.isSupported {
                        BarcodeScannerView { ean in Task { await lookup(ean: ean) } }
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
                    } else {
                        Text("Scan caméra indisponible sur cet appareil — utilisez la saisie manuelle.")
                            .font(BDTheme.sans(13)).foregroundColor(BDTheme.text3)
                    }
                } else {
                    HStack {
                        TextField("EAN / ISBN", text: $manualEAN)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Button("Chercher") { Task { await lookup(ean: manualEAN) } }
                            .buttonStyle(.bdPrimary)
                    }
                }

                if isSearching { ProgressView().tint(BDTheme.accent) }
                if let errorMessage {
                    Text(errorMessage).font(BDTheme.sans(12.5)).foregroundColor(BDTheme.red)
                }
                if let found {
                    SearchResultRow(
                        result: found,
                        onAddToCollection: { pickingCollectionFor = found },
                        onAddToWishlist: { addToWishlist(found); dismiss() }
                    )
                }
                Spacer()
            }
            .padding(16)
            .background(BDTheme.bg2.ignoresSafeArea())
            .navigationTitle("Scanner un album")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $pickingCollectionFor) { result in
                CollectionPickerSheet(result: result) { collectionIds in
                    addToCollection(result, collectionIds: collectionIds)
                    dismiss()
                }
            }
        }
    }

    private func lookup(ean: String) async {
        let trimmed = ean.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let results = try await GoogleBooksService.searchByISBN(trimmed)
            found = results.first
            if found == nil { errorMessage = "Aucun résultat pour cet EAN." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addToCollection(_ result: SearchResult, collectionIds: [UUID]) {
        library.addBookEnriching(Book(
            bdgestId: result.bdgestId, title: result.title, series: result.series, tome: result.tome,
            author: result.author, illustrator: result.illustrator, publisher: result.publisher,
            year: result.year, genre: result.genre, ean: result.ean, coverURL: result.coverURL,
            synopsis: result.synopsis, collectionIds: collectionIds
        ))
    }

    private func addToWishlist(_ result: SearchResult) {
        library.addWishlistItem(WishlistItem(
            bdgestId: result.bdgestId, title: result.title, series: result.series, tome: result.tome,
            author: result.author, publisher: result.publisher, year: result.year, coverURL: result.coverURL
        ))
    }
}

@available(iOS 16.0, *)
@MainActor
private enum DataScannerAvailability {
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }
}
