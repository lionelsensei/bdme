import SwiftUI

/// Ligne album en vue liste — équivalent .book-row.
struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: book.coverURL.flatMap(URL.init(string:))) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    BDTheme.bg4
                }
            }
            .frame(width: 40, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(BDTheme.sans(14.4))
                    .foregroundColor(BDTheme.text)
                    .lineLimit(1)
                Text(metaLine)
                    .font(BDTheme.sans(12.5))
                    .foregroundColor(BDTheme.text3)
                    .lineLimit(1)
            }

            Spacer()
            StatusDot(status: book.readStatus)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(BDTheme.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous)
                .stroke(BDTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
    }

    private var metaLine: String {
        [book.author, book.year.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
