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
    @State private var confirmingDelete = false

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
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: book.coverURL.flatMap(URL.init(string:))) { phase in
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

    /// Si bdgestId présent et auteur/couverture manquants, enrichit via la
    /// source d'origine puis persiste les champs manquants.
    private func enrichIfNeeded() async {
        guard let bdgestId = book.bdgestId,
              book.author == nil || book.coverURL == nil else { return }
        isEnriching = true
        defer { isEnriching = false }

        do {
            let details: SearchResult
            if bdgestId.hasPrefix("bdg:") {
                details = try await BDGestProxyService.fetchDetails(bdgestId: bdgestId)
            } else {
                details = try await GoogleBooksService.fetchDetails(volumeId: bdgestId)
            }
            book.author = book.author ?? details.author
            book.illustrator = book.illustrator ?? details.illustrator
            book.publisher = book.publisher ?? details.publisher
            book.genre = book.genre ?? details.genre
            book.synopsis = book.synopsis ?? details.synopsis
            book.ean = book.ean ?? details.ean
            book.coverURL = book.coverURL ?? details.coverURL
            library.updateBook(book)
        } catch {
            // Enrichissement best-effort : on garde les données locales si ça échoue.
        }
    }
}
