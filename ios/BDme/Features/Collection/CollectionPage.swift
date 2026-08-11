import SwiftUI

/// Équivalent de CollectionPage.jsx : groupement par série, vue dossiers
/// deux niveaux, filtres de statut, recherche locale, grille/liste.
struct CollectionPage: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var viewMode: ViewMode = .grid
    @State private var groupBySeries = true
    @State private var statusFilter: ReadStatus?
    @State private var query = ""
    @State private var openedSeries: String?
    @State private var selectedBook: Book?
    @State private var showScanSheet = false
    @State private var showManageCollections = false
    @State private var collectionFilter: BookCollection?

    enum ViewMode { case grid, list }

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if openedSeries == nil {
                        searchAndFilters
                    } else {
                        breadcrumb
                    }
                    content
                }
                .padding(16)
            }
            .background(BDTheme.bg.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showScanSheet = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 22))
                        .foregroundColor(BDTheme.bg)
                        .frame(width: 52, height: 52)
                        .background(BDTheme.accent)
                        .clipShape(Circle())
                        .shadow(color: BDTheme.accent.opacity(0.35), radius: 12, y: 4)
                }
                .padding(20)
            }
            .navigationTitle("Collection")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showManageCollections = true
                    } label: {
                        Image(systemName: "folder")
                    }
                    Button {
                        withAnimation { groupBySeries.toggle(); openedSeries = nil }
                    } label: {
                        Label("Séries", systemImage: groupBySeries ? "square.grid.2x2.fill" : "square.grid.2x2")
                    }
                    Button {
                        viewMode = viewMode == .grid ? .list : .grid
                    } label: {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                    }
                }
            }
            .sheet(item: $selectedBook) { book in
                BookDetailModal(book: book)
            }
            .sheet(isPresented: $showScanSheet) {
                ScanSheet()
            }
            .sheet(isPresented: $showManageCollections) {
                ManageCollectionsSheet()
            }
        }
    }

    // MARK: Filtrage

    private var filteredBooks: [Book] {
        library.books.filter { book in
            (statusFilter == nil || book.readStatus == statusFilter)
                && (collectionFilter == nil || book.collectionIds.contains(collectionFilter!.id))
                && (query.isEmpty || book.title.localizedCaseInsensitiveContains(query)
                    || (book.series?.localizedCaseInsensitiveContains(query) ?? false))
        }
    }

    private var groupedBySeries: [(series: String?, books: [Book])] {
        let grouped = Dictionary(grouping: filteredBooks) { $0.series }
        let named = grouped.filter { $0.key != nil }
            .sorted { ($0.key ?? "").localizedCompare($1.key ?? "") == .orderedAscending }
            .map { (series: $0.key, books: $0.value) }
        let unnamed = grouped[nil].map { [(series: Optional<String>.none, books: $0)] } ?? []
        return named + unnamed
    }

    // MARK: Sous-vues

    @ViewBuilder
    private var searchAndFilters: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(BDTheme.text3)
            TextField("Rechercher…", text: $query)
                .foregroundColor(BDTheme.text)
        }
        .padding(10)
        .background(BDTheme.bg3)
        .clipShape(RoundedRectangle(cornerRadius: BDTheme.radiusSm, style: .continuous))

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "Tous")
                filterChip(.unread, label: "Non lu")
                filterChip(.reading, label: "En cours")
                filterChip(.read, label: "Lu")
            }
        }

        if !library.collections.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    collectionChip(nil, label: "Toutes les collections")
                    ForEach(library.collections) { collection in
                        collectionChip(collection, label: collection.name)
                    }
                }
            }
        }
    }

    private func collectionChip(_ collection: BookCollection?, label: String) -> some View {
        Button {
            withAnimation { collectionFilter = collection; openedSeries = nil }
        } label: {
            Text(label)
                .font(BDTheme.sans(12.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(collectionFilter?.id == collection?.id ? BDTheme.accentBg : Color.clear)
                .foregroundColor(collectionFilter?.id == collection?.id ? BDTheme.accent : BDTheme.text3)
                .overlay(
                    Capsule().stroke(collectionFilter?.id == collection?.id ? BDTheme.accent.opacity(0.3) : BDTheme.border2, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }

    private func filterChip(_ status: ReadStatus?, label: String) -> some View {
        Button {
            statusFilter = status
        } label: {
            Text(label)
                .font(BDTheme.sans(12.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(statusFilter == status ? BDTheme.accentBg : Color.clear)
                .foregroundColor(statusFilter == status ? BDTheme.accent : BDTheme.text3)
                .overlay(
                    Capsule().stroke(statusFilter == status ? BDTheme.accent.opacity(0.3) : BDTheme.border2, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Button("← Séries") { withAnimation { openedSeries = nil } }
                .font(BDTheme.sans(13))
                .foregroundColor(BDTheme.accent)
            Text("· \(openedSeries ?? "") · \(booksInOpenedSeries.count) albums")
                .font(BDTheme.sans(13))
                .foregroundColor(BDTheme.text3)
        }
    }

    private var booksInOpenedSeries: [Book] {
        filteredBooks
            .filter { $0.series == openedSeries }
            .sorted {
                switch ($0.tome, $1.tome) {
                case let (a?, b?): return a < b
                case (nil, nil): return ($0.year ?? 0) < ($1.year ?? 0)
                case (nil, _): return false
                case (_, nil): return true
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if !groupBySeries || collectionFilter != nil {
            bookCollection(filteredBooks)
        } else if let openedSeries {
            bookCollection(booksInOpenedSeries.filter { $0.series == openedSeries })
        } else if filteredBooks.isEmpty {
            emptyState
        } else {
            folderCollection
        }
    }

    @ViewBuilder
    private var folderCollection: some View {
        if viewMode == .grid {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(groupedBySeries, id: \.series) { group in
                    Button {
                        if let series = group.series { withAnimation { openedSeries = series } }
                    } label: {
                        SeriesFolderCard(name: group.series ?? "Albums sans série", books: group.books)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(groupedBySeries, id: \.series) { group in
                    Button {
                        if let series = group.series { withAnimation { openedSeries = series } }
                    } label: {
                        HStack {
                            Text(group.series ?? "Albums sans série")
                                .font(BDTheme.sans(14))
                                .foregroundColor(BDTheme.text)
                            Spacer()
                            Text("\(group.books.count)")
                                .font(BDTheme.sans(12))
                                .foregroundColor(BDTheme.text3)
                            Image(systemName: "chevron.right")
                                .foregroundColor(BDTheme.text3)
                        }
                        .padding(12)
                        .background(BDTheme.bg2)
                        .overlay(RoundedRectangle(cornerRadius: BDTheme.radius).stroke(BDTheme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func bookCollection(_ books: [Book]) -> some View {
        if books.isEmpty {
            emptyState
        } else if viewMode == .grid {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(books) { book in
                    Button { selectedBook = book } label: { BookCard(book: book) }
                        .buttonStyle(.plain)
                }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(books) { book in
                    Button { selectedBook = book } label: { BookRow(book: book) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📚").font(.system(size: 40)).opacity(0.5)
            Text("Aucun album").font(BDTheme.serif(18)).foregroundColor(BDTheme.text2)
            Text("Ajoutez des albums depuis la recherche.")
                .font(BDTheme.sans(13.5)).foregroundColor(BDTheme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
