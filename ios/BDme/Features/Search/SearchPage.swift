import SwiftUI

/// Équivalent de SearchPage.jsx : dropdown 4 sources, pagination, ajout
/// collection/wishlist. Amazon reste géré côté client (redirection Safari).
struct SearchPage: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var source: SearchSource = .bdgest
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var startIndex = 0
    @State private var totalItems = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pickingCollectionFor: SearchResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Source", selection: $source) {
                    ForEach(SearchSource.allCases) { source in
                        Text(source.label).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(BDTheme.text3)
                    TextField("Titre, série, auteur…", text: $query)
                        .foregroundColor(BDTheme.text)
                        .onSubmit { Task { await runSearch(reset: true) } }
                }
                .padding(10)
                .background(BDTheme.bg3)
                .clipShape(RoundedRectangle(cornerRadius: BDTheme.radiusSm, style: .continuous))

                if let errorMessage {
                    Text(errorMessage).font(BDTheme.sans(12.5)).foregroundColor(BDTheme.red)
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(results) { result in
                            SearchResultRow(
                                result: result,
                                onAddToCollection: { pickingCollectionFor = result },
                                onAddToWishlist: { addToWishlist(result) }
                            )
                        }
                        if isLoading {
                            ProgressView().tint(BDTheme.accent).padding()
                        } else if !results.isEmpty && results.count < totalItems {
                            Button("Charger plus") { Task { await runSearch(reset: false) } }
                                .buttonStyle(.bdGhost)
                        }
                    }
                }
            }
            .padding(16)
            .background(BDTheme.bg.ignoresSafeArea())
            .navigationTitle("Recherche")
            .onChange(of: source) { _ in Task { await runSearch(reset: true) } }
            .sheet(item: $pickingCollectionFor) { result in
                CollectionPickerSheet(result: result) { collectionIds in
                    addToCollection(result, collectionIds: collectionIds)
                }
            }
        }
    }

    private func runSearch(reset: Bool) async {
        guard !query.isEmpty else { return }
        if source == .amazon {
            if let url = URL(string: "https://www.amazon.fr/s?i=stripbooks&k=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                await UIApplication.shared.open(url)
            }
            return
        }

        if reset { startIndex = 0; results = [] }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page: SearchPageResult
            switch source {
            case .googlebooks: page = try await GoogleBooksService.search(query: query, startIndex: startIndex)
            case .openlibrary: page = try await OpenLibraryService.search(query: query, startIndex: startIndex)
            case .bdgest: page = try await BDGestProxyService.search(query: query, startIndex: startIndex)
            case .amazon: return
            }
            results.append(contentsOf: page.results)
            totalItems = page.totalItems
            startIndex += page.results.count
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
