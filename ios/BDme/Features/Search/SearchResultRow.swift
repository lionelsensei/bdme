import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult
    let onAddToCollection: () -> Void
    let onAddToWishlist: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: result.coverURL.flatMap(URL.init(string:))) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    BDTheme.bg4
                }
            }
            .frame(width: 52, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title).font(BDTheme.sans(14.5)).foregroundColor(BDTheme.text)
                Text(metaLine).font(BDTheme.sans(12)).foregroundColor(BDTheme.text3)

                HStack(spacing: 6) {
                    Button("+ Collection", action: onAddToCollection)
                        .buttonStyle(.bdPrimary)
                    Button("+ Souhaits", action: onAddToWishlist)
                        .buttonStyle(.bdGhost)
                }
                .font(BDTheme.sans(12))
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(BDTheme.bg2)
        .overlay(RoundedRectangle(cornerRadius: BDTheme.radius).stroke(BDTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
    }

    private var metaLine: String {
        [result.series, result.author, result.year.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
