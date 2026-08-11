import SwiftUI

/// Équivalent de CollectionPage.jsx : groupement par série ou par collection
/// perso, vue dossiers deux niveaux, filtres de statut, recherche locale,
/// grille/liste, actions rapides par appui long.
struct CollectionPage: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var viewMode: ViewMode = .grid
    @State private var groupMode: GroupMode = .series
    @State private var statusFilter: ReadStatus?
    @State private var query = ""
    @State private var openedSeries: String?
    @State private var openedCollection: BookCollection?
    @State private var selectedBook: Book?
    @State private var showScanSheet = false
    @State private var showManageCollections = false
    @State private var pendingDeleteBook: Book?

    enum ViewMode { case grid, list }
    enum GroupMode { case none, series, collection }

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if openedSeries == nil && openedCollection == nil {
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
                    Menu {
                        Button {
                            withAnimation { groupMode = .none; openedSeries = nil; openedCollection = nil }
                        } label: {
                            if groupMode == .none { Label("Aucun groupement", systemImage: "checkmark") }
                            else { Text("Aucun groupement") }
                        }
                        Button {
                            withAnimation { groupMode = .series; openedSeries = nil; openedCollection = nil }
                        } label: {
                            if groupMode == .series { Label("Par série", systemImage: "checkmark") }
                            else { Text("Par série") }
                        }
                        Button {
                            withAnimation { groupMode = .collection; openedSeries = nil; openedCollection = nil }
                        } label: {
                            if groupMode == .collection { Label("Par collection", systemImage: "checkmark") }
                            else { Text("Par collection") }
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
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
            .alert(item: $pendingDeleteBook) { book in
                Alert(
                    title: Text("Supprimer « \(book.title) » ?"),
                    message: Text("Cette action est définitive."),
                    primaryButton: .destructive(Text("Supprimer")) {
                        library.deleteBook(book)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // MARK: Filtrage

    private var filteredBooks: [Book] {
        library.books.filter { book in
            (statusFilter == nil || book.readStatus == statusFilter)
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

    private var groupedByCollection: [(collection: BookCollection, books: [Book])] {
        library.collections.compactMap { collection in
            let books = filteredBooks.filter { $0.collectionIds.contains(collection.id) }
            return books.isEmpty ? nil : (collection: collection, books: books)
        }
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
            Button(openedCollection != nil ? "← Collections" : "← Séries") {
                withAnimation { openedSeries = nil; openedCollection = nil }
            }
            .font(BDTheme.sans(13))
            .foregroundColor(BDTheme.accent)

            if let openedCollection {
                Text("· \(openedCollection.name) · \(library.books(in: openedCollection).count) albums")
                    .font(BDTheme.sans(13))
                    .foregroundColor(BDTheme.text3)
            } else {
                Text("· \(openedSeries ?? "") · \(booksInOpenedSeries.count) albums")
                    .font(BDTheme.sans(13))
                    .foregroundColor(BDTheme.text3)
            }
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
        if let openedCollection {
            bookCollection(filteredBooks.filter { $0.collectionIds.contains(openedCollection.id) }, currentCollection: openedCollection)
        } else if let openedSeries {
            bookCollection(booksInOpenedSeries.filter { $0.series == openedSeries })
        } else {
            switch groupMode {
            case .none:
                bookCollection(filteredBooks)
            case .series:
                if filteredBooks.isEmpty { emptyState } else { folderCollectionBySeries }
            case .collection:
                if groupedByCollection.isEmpty { emptyCollectionsState } else { folderCollectionByCollection }
            }
        }
    }

    @ViewBuilder
    private var folderCollectionBySeries: some View {
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
                        folderRow(title: group.series ?? "Albums sans série", count: group.books.count)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var folderCollectionByCollection: some View {
        if viewMode == .grid {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(groupedByCollection, id: \.collection.id) { group in
                    Button {
                        withAnimation { openedCollection = group.collection }
                    } label: {
                        SeriesFolderCard(name: group.collection.name, books: group.books)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(groupedByCollection, id: \.collection.id) { group in
                    Button {
                        withAnimation { openedCollection = group.collection }
                    } label: {
                        folderRow(title: group.collection.name, count: group.books.count)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func folderRow(title: String, count: Int) -> some View {
        HStack {
            Text(title).font(BDTheme.sans(14)).foregroundColor(BDTheme.text)
            Spacer()
            Text("\(count)").font(BDTheme.sans(12)).foregroundColor(BDTheme.text3)
            Image(systemName: "chevron.right").foregroundColor(BDTheme.text3)
        }
        .padding(12)
        .background(BDTheme.bg2)
        .overlay(RoundedRectangle(cornerRadius: BDTheme.radius).stroke(BDTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
    }

    @ViewBuilder
    private func bookCollection(_ books: [Book], currentCollection: BookCollection? = nil) -> some View {
        if books.isEmpty {
            emptyState
        } else if viewMode == .grid {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(books) { book in
                    Button { selectedBook = book } label: { BookCard(book: book) }
                        .buttonStyle(.plain)
                        .contextMenu { contextMenuItems(for: book, currentCollection: currentCollection) }
                }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(books) { book in
                    Button { selectedBook = book } label: { BookRow(book: book) }
                        .buttonStyle(.plain)
                        .contextMenu { contextMenuItems(for: book, currentCollection: currentCollection) }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(for book: Book, currentCollection: BookCollection?) -> some View {
        ForEach(ReadStatus.allCases, id: \.self) { status in
            Button {
                var updated = book
                updated.readStatus = status
                library.updateBook(updated)
            } label: {
                if book.readStatus == status {
                    Label("Marquer « \(status.label) »", systemImage: "checkmark")
                } else {
                    Text("Marquer « \(status.label) »")
                }
            }
        }
        if let currentCollection {
            Button {
                var ids = book.collectionIds
                ids.removeAll { $0 == currentCollection.id }
                library.setCollections(ids, for: book)
            } label: {
                Label("Retirer de « \(currentCollection.name) »", systemImage: "folder.badge.minus")
            }
        }
        Button(role: .destructive) {
            pendingDeleteBook = book
        } label: {
            Label("Supprimer de ma bibliothèque", systemImage: "trash")
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

    private var emptyCollectionsState: some View {
        VStack(spacing: 12) {
            Text("📁").font(.system(size: 40)).opacity(0.5)
            Text("Aucune collection").font(BDTheme.serif(18)).foregroundColor(BDTheme.text2)
            Text("Crée une collection depuis l'icône dossier, ou en ajoutant un album depuis la recherche.")
                .font(BDTheme.sans(13.5)).foregroundColor(BDTheme.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
