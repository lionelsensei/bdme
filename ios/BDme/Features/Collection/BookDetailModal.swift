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
