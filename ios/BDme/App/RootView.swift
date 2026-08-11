import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            CollectionPage()
                .tabItem { Label("Collection", systemImage: "books.vertical.fill") }

            SearchPage()
                .tabItem { Label("Recherche", systemImage: "magnifyingglass") }

            WishlistPage()
                .tabItem { Label("Souhaits", systemImage: "heart.fill") }

            SettingsPage()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
        .tint(BDTheme.accent)
    }
}
