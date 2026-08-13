import SwiftUI

/// Équivalent du BookModal dans BookCard.jsx : enrichissement auto,
/// statut de lecture, édition de la série avec autocomplétion.
struct BookDetailModal: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State var book: Book
    @State private var editingSeries = false
    @State private var seriesDraft = ""
    @State private var isEnriching = false
    @State private var enrichError: String?
    @State private var confirmingDelete = false
    @State private var seriesTomes: [SeriesTome] = []
    @State private var isLoadingTomes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let tome = book.tome {
                        Text("#\(tome)").font(BDTheme.serif(34)).foregroundColor(BDTheme.accent)
                    }
                    statusButtons
                    authorsSection
                    if let synopsis = book.synopsis, !synopsis.isEmpty {
                        Text(synopsis).font(BDTheme.sans(13.5)).foregroundColor(BDTheme.text2)
                    }
                    refreshSection
                    missingTomesSection
                    collectionsSection
                    deleteSection
                }
                .padding(20)
            }
            .background(BDTheme.bg2.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .task { await enrichIfNeeded() }
        .task { await loadSeriesTomes() }
    }

    @ViewBuilder
    private var refreshSection: some View {
        if book.author == nil || book.synopsis == nil {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if isEnriching {
                        ProgressView().tint(BDTheme.accent)
                    } else {
                        Button("Rafraîchir les infos") {
                            Task { await enrichIfNeeded(force: true) }
                        }
                        .buttonStyle(.bdGhost)
                        .font(BDTheme.sans(12.5))
                    }
                    Text("Fiche incomplète").font(BDTheme.sans(12)).foregroundColor(BDTheme.text3)
                }
                if let enrichError {
                    Text(enrichError).font(BDTheme.sans(11.5)).foregroundColor(BDTheme.red)
                }
            }
        }
    }

    @ViewBuilder
    private var missingTomesSection: some View {
        let missing = missingTomes
        if isLoadingTomes {
            ProgressView().tint(BDTheme.accent)
        } else if !missing.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tomes manquants de la série").font(BDTheme.sans(12.5)).foregroundColor(BDTheme.text3)
                ForEach(missing) { tome in
                    HStack(spacing: 10) {
                        CachedAsyncImage(url: tome.coverURL.flatMap(URL.init(string:))) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                BDTheme.bg3
                            }
                        }
                        .frame(width: 32, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

                        VStack(alignment: .leading, spacing: 1) {
                            if let n = tome.tome { Text("Tome \(n)").font(BDTheme.sans(12.5)).foregroundColor(BDTheme.text) }
                            if let title = tome.title { Text(title).font(BDTheme.sans(11.5)).foregroundColor(BDTheme.text3).lineLimit(1) }
                        }
                        Spacer()
                        Button("Ajouter") {
                            addMissingTome(tome)
                        }
                        .buttonStyle(.bdGhost)
                        .font(BDTheme.sans(11.5))
                    }
                }
            }
        }
    }

    /// Tomes présents sur la fiche série mais absents de la bibliothèque
    /// (comparaison par bdgestId, repli sur le numéro de tome).
    private var missingTomes: [SeriesTome] {
        guard !seriesTomes.isEmpty else { return [] }
        let ownedIds = Set(library.books.compactMap { $0.bdgestId })
        let ownedTomeNumbers = Set(
            library.books
                .filter { $0.series?.localizedCaseInsensitiveCompare(book.series ?? "") == .orderedSame }
                .compactMap { $0.tome }
        )
        return seriesTomes.filter { tome in
            !ownedIds.contains(tome.bdgestId) && !(tome.tome.map(ownedTomeNumbers.contains) ?? false)
        }
    }

    private func loadSeriesTomes() async {
        guard let seriesBdgestId = book.seriesBdgestId else { return }
        isLoadingTomes = true
        defer { isLoadingTomes = false }
        seriesTomes = (try? await BDGestProxyService.fetchSeriesTomes(seriesBdgestId: seriesBdgestId)) ?? []
    }

    private func addMissingTome(_ tome: SeriesTome) {
        seriesTomes.removeAll { $0.id == tome.id }
        library.addBookEnriching(Book(
            bdgestId: tome.bdgestId,
            title: tome.title ?? book.series ?? "Sans titre",
            series: book.series,
            tome: tome.tome,
            coverURL: tome.coverURL,
            seriesBdgestId: book.seriesBdgestId
        ))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            CachedAsyncImage(url: book.coverURL.flatMap(URL.init(string:))) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    BDTheme.bg3
                }
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: BDTheme.radiusSm, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title).font(BDTheme.serif(19)).foregroundColor(BDTheme.text)

                HStack(spacing: 6) {
                    if editingSeries {
                        TextField("Série", text: $seriesDraft, onCommit: commitSeries)
                            .font(BDTheme.sans(13))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(book.series ?? "Sans série")
                            .font(BDTheme.sans(13))
                            .foregroundColor(BDTheme.text2)
                        Button {
                            seriesDraft = book.series ?? ""
                            editingSeries = true
                        } label: {
                            Image(systemName: "pencil").font(.system(size: 11))
                        }
                        .foregroundColor(BDTheme.text3)
                    }
                }
            }
        }
    }

    private var statusButtons: some View {
        HStack(spacing: 8) {
            ForEach(ReadStatus.allCases, id: \.self) { status in
                Button {
                    book.readStatus = status
                    library.updateBook(book)
                } label: {
                    Text(status.label)
                        .font(BDTheme.sans(12.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(book.readStatus == status ? statusColor(status).opacity(0.15) : BDTheme.bg3)
                        .foregroundColor(book.readStatus == status ? statusColor(status) : BDTheme.text2)
                        .clipShape(RoundedRectangle(cornerRadius: BDTheme.radiusSm, style: .continuous))
                }
            }
        }
    }

    private func statusColor(_ status: ReadStatus) -> Color {
        switch status {
        case .read: return BDTheme.green
        case .reading: return BDTheme.accent
        case .unread: return BDTheme.text2
        }
    }

    @ViewBuilder
    private var authorsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let author = book.author {
                Text(book.illustrator == author || book.illustrator == nil
                     ? author
                     : "\(author) (scénario)")
                    .font(BDTheme.sans(13))
                    .foregroundColor(BDTheme.text2)
            }
            if let illustrator = book.illustrator, illustrator != book.author {
                Text("\(illustrator) (dessin)")
                    .font(BDTheme.sans(13))
                    .foregroundColor(BDTheme.text2)
            }
            if let publisher = book.publisher {
                Text(publisher).font(BDTheme.sans(12.5)).foregroundColor(BDTheme.text3)
            }
            if let genre = book.genre {
                Text(genre).font(BDTheme.sans(12.5)).foregroundColor(BDTheme.text3)
            }
        }
    }

    @ViewBuilder
    private var collectionsSection: some View {
        if !library.collections.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Collections").font(BDTheme.sans(12.5)).foregroundColor(BDTheme.text3)
                FlowChips(items: library.collections) { collection in
                    let isMember = book.collectionIds.contains(collection.id)
                    Button {
                        toggleCollection(collection)
                    } label: {
                        Text(collection.name)
                            .font(BDTheme.sans(12.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isMember ? BDTheme.accentBg : BDTheme.bg3)
                            .foregroundColor(isMember ? BDTheme.accent : BDTheme.text2)
                            .overlay(
                                Capsule().stroke(isMember ? BDTheme.accent.opacity(0.3) : BDTheme.border2, lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func toggleCollection(_ collection: BookCollection) {
        var ids = book.collectionIds
        if let idx = ids.firstIndex(of: collection.id) {
            ids.remove(at: idx)
        } else {
            ids.append(collection.id)
        }
        book.collectionIds = ids
        library.updateBook(book)
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(BDTheme.border)
            if confirmingDelete {
                HStack {
                    Text("Supprimer définitivement cet album ?")
                        .font(BDTheme.sans(12.5))
                        .foregroundColor(BDTheme.text2)
                    Spacer()
                    Button("Annuler") { confirmingDelete = false }
                        .buttonStyle(.bdGhost)
                    Button("Supprimer") {
                        library.deleteBook(book)
                        dismiss()
                    }
                    .foregroundColor(BDTheme.red)
                }
            } else {
                Button("Supprimer de ma collection") {
                    confirmingDelete = true
                }
                .foregroundColor(BDTheme.red)
                .font(BDTheme.sans(13))
            }
        }
    }

    private func commitSeries() {
        editingSeries = false
        book.series = seriesDraft.trimmingCharacters(in: .whitespaces).isEmpty ? nil : seriesDraft
        library.updateBook(book)
    }

    /// Filet de sécurité : si l'enrichissement proactif à l'ajout (voir
    /// LibraryStore.addBookEnriching) n'a pas eu lieu ou a échoué, on
    /// retente à l'ouverture du détail. Idempotent (BookEnricher ne fait
    /// rien si les infos sont déjà là). `force: true` (bouton manuel)
    /// affiche l'erreur au lieu de l'avaler silencieusement.
    private func enrichIfNeeded(force: Bool = false) async {
        isEnriching = true
        enrichError = nil
        defer { isEnriching = false }
        do {
            book = try await BookEnricher.enrich(book)
            library.updateBook(book)
        } catch is BookEnricher.Skip {
            // Rien à faire.
        } catch {
            if force { enrichError = error.localizedDescription }
        }
    }
}
