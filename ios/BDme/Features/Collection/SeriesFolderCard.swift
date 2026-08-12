import SwiftUI

/// Carte dossier de série (vue grille) — empile jusqu'à 3 couvertures dans
/// un seul cadre 2:3 partagé (chaque pochette est juste pivotée/réduite,
/// pas positionnée indépendamment), équivalent SeriesFolderCard.jsx.
struct SeriesFolderCard: View {
    let name: String
    let books: [Book]

    private var stack: [Book] { Array(books.prefix(3)) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack {
                    // Du fond vers l'avant : la dernière pochette dessinée
                    // (index 0) apparaît au premier plan, sans transformation.
                    ForEach(stack.indices.reversed(), id: \.self) { index in
                        cover(stack[index], size: geo.size)
                            .rotationEffect(.degrees(rotation(for: index)))
                            .scaleEffect(scale(for: index))
                            .opacity(opacity(for: index))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(2/3, contentMode: .fit)
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

    private func cover(_ book: Book, size: CGSize) -> some View {
        AsyncImage(url: book.coverURL.flatMap(URL.init(string:))) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    BDTheme.bg3
                    Text(book.title)
                        .font(BDTheme.serif(11))
                        .foregroundColor(BDTheme.text3)
                        .multilineTextAlignment(.center)
                        .padding(6)
                        .lineLimit(3)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous)
                .stroke(BDTheme.border, lineWidth: 1)
        )
    }

    private func rotation(for index: Int) -> Double {
        [0.0, 2.0, 4.0][safe: index] ?? 0
    }
    private func scale(for index: Int) -> Double {
        [1.0, 0.95, 0.91][safe: index] ?? 1.0
    }
    private func opacity(for index: Int) -> Double {
        [1.0, 0.85, 0.7][safe: index] ?? 1.0
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
