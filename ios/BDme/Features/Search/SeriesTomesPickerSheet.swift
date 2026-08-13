import SwiftUI

/// Sheet ouverte quand un résultat de recherche BDGest est une série
/// entière (voir SearchResult.isSeries) : liste ses tomes et laisse
/// choisir lequel ajouter à la collection ou aux souhaits.
struct SeriesTomesPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let series: SearchResult
    let onAddToCollection: (SearchResult) -> Void
    let onAddToWishlist: (SearchResult) -> Void

    @State private var tomes: [SeriesTome] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(BDTheme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage).font(BDTheme.sans(13)).foregroundColor(BDTheme.red).padding()
                } else if tomes.isEmpty {
                    Text("Aucun tome trouvé pour cette série.")
                        .font(BDTheme.sans(13)).foregroundColor(BDTheme.text3).padding()
                } else {
                    List(tomes) { tome in
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: tome.coverURL.flatMap(URL.init(string:))) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    BDTheme.bg4
                                }
                            }
                            .frame(width: 40, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tomeLabel(tome)).font(BDTheme.sans(14)).foregroundColor(BDTheme.text)
                                if let title = tome.title, !title.isEmpty {
                                    Text(title).font(BDTheme.sans(12)).foregroundColor(BDTheme.text3).lineLimit(1)
                                }
                            }
                            Spacer()
                            Button("+ Collection") { onAddToCollection(asSearchResult(tome)); dismiss() }
                                .buttonStyle(.bdPrimary).font(BDTheme.sans(11.5))
                            Button("+ Souhaits") { onAddToWishlist(asSearchResult(tome)); dismiss() }
                                .buttonStyle(.bdGhost).font(BDTheme.sans(11.5))
                        }
                        .listRowBackground(BDTheme.bg2)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(BDTheme.bg.ignoresSafeArea())
            .navigationTitle(series.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func tomeLabel(_ tome: SeriesTome) -> String {
        tome.tome.map { "Tome \($0)" } ?? (tome.title ?? "Tome")
    }

    private func asSearchResult(_ tome: SeriesTome) -> SearchResult {
        SearchResult(
            bdgestId: tome.bdgestId,
            title: tome.title.map { "\(series.title) - \($0)" } ?? series.title,
            series: series.title,
            tome: tome.tome,
            author: nil, illustrator: nil, publisher: nil, year: nil, genre: nil, ean: nil,
            coverURL: tome.coverURL, synopsis: nil
        )
    }

    private func load() async {
        do {
            tomes = try await BDGestProxyService.fetchSeriesTomes(seriesBdgestId: series.bdgestId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
