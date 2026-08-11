import SwiftUI

/// Carte album en grille — équivalent .book-card.
struct BookCard: View {
    let book: Book

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geo in
                AsyncImage(url: book.coverURL.flatMap(URL.init(string:))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        ZStack {
                            BDTheme.bg3
                            Text(book.title)
                                .font(BDTheme.serif(13))
                                .foregroundColor(BDTheme.text3)
                                .multilineTextAlignment(.center)
                                .padding(12)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .aspectRatio(2/3, contentMode: .fit)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 60)
                    .overlay(alignment: .bottomLeading) {
                        Text(book.title)
                            .font(BDTheme.sans(11))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .padding(10)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous)
                    .stroke(BDTheme.border, lineWidth: 1)
            )

            StatusDot(status: book.readStatus)
                .padding(8)
        }
    }
}
