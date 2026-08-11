import SwiftUI

/// Équivalent de WishlistPage.jsx.
struct WishlistPage: View {
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if library.wishlist.isEmpty {
                        emptyState
                    } else {
                        ForEach(library.wishlist) { item in
                            WishlistRow(item: item) {
                                library.deleteWishlistItem(item)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(BDTheme.bg.ignoresSafeArea())
            .navigationTitle("Souhaits")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("♡").font(.system(size: 40)).opacity(0.5)
            Text("Liste de souhaits vide").font(BDTheme.serif(18)).foregroundColor(BDTheme.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct WishlistRow: View {
    let item: WishlistItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.coverURL.flatMap(URL.init(string:))) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    BDTheme.bg4
                }
            }
            .frame(width: 36, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(BDTheme.sans(14)).foregroundColor(BDTheme.text).lineLimit(1)
                if let series = item.series {
                    Text(series).font(BDTheme.sans(12)).foregroundColor(BDTheme.text3)
                }
            }
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash").foregroundColor(BDTheme.red)
            }
        }
        .padding(12)
        .background(BDTheme.bg2)
        .overlay(RoundedRectangle(cornerRadius: BDTheme.radius).stroke(BDTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: BDTheme.radius, style: .continuous))
    }
}
