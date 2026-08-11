import SwiftUI

/// Carte dossier de série (vue grille) — empile jusqu'à 3 couvertures,
/// équivalent SeriesFolderCard.jsx.
struct SeriesFolderCard: View {
    let name: String
    let books: [Book]

    private var stack: [Book] { Array(books.prefix(3)) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ForEach(Array(stack.enumerated()), id: \.element.id) { index, book in
                    AsyncImage(url: book.coverURL.flatMap(URL.init(string:))) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            BDTheme.bg3
                        }
                    }
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous)
                            .stroke(BDTheme.border, lineWidth: 1)
                    )
                    .rotationEffect(.degrees(rotation(for: index)))
                    .offset(offset(for: index))
                }
            }
            .overlay(alignment: .topTrailing) {
                Text("\(books.count)")
                    .font(BDTheme.sans(11, weight: .medium))
                    .foregroundColor(BDTheme.bg)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(BDTheme.accent)
                    .clipShape(Capsule())
                    .padding(6)
            }

            Text(name)
                .font(BDTheme.sans(12.5))
                .foregroundColor(BDTheme.text)
                .lineLimit(1)
        }
    }

    private func rotation(for index: Int) -> Double {
        [0.0, -6.0, 6.0][safe: stack.count - 1 - index] ?? 0
    }
    private func offset(for index: Int) -> CGSize {
        let step = 3.0
        return CGSize(width: Double(index) * step, height: -Double(index) * step)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
