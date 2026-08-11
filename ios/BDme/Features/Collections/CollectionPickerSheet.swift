import SwiftUI

/// Sheet affichée à l'ajout d'un album (recherche ou scan) pour choisir sa
/// ou ses collections perso de destination, avec suggestion basée sur les
/// métadonnées du résultat. Peut aussi rester sans collection (bibliothèque
/// seule), ou en créer une nouvelle à la volée.
struct CollectionPickerSheet: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    let result: SearchResult
    let onConfirm: ([UUID]) -> Void

    @State private var selected: Set<UUID> = []
    @State private var newCollectionName = ""
    @State private var showNewCollectionField = false

    private var suggested: [BookCollection] {
        library.suggestedCollections(for: result)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(result.title)
                        .font(BDTheme.serif(17))
                        .foregroundColor(BDTheme.text)
                    if let meta = metaLine {
                        Text(meta).font(BDTheme.sans(12.5)).foregroundColor(BDTheme.text3)
                    }
                }

                if !suggested.isEmpty {
                    Section("Suggéré") {
                        ForEach(suggested) { collection in
                            collectionRow(collection)
                        }
                    }
                }

                let others = library.collections.filter { c in !suggested.contains { $0.id == c.id } }
                if !others.isEmpty {
                    Section("Toutes mes collections") {
                        ForEach(others) { collection in
                            collectionRow(collection)
                        }
                    }
                }

                Section {
                    if showNewCollectionField {
                        HStack {
                            TextField("Nom de la nouvelle collection", text: $newCollectionName)
                            Button("Créer") {
                                let created = library.createCollection(name: newCollectionName.trimmingCharacters(in: .whitespaces))
                                selected.insert(created.id)
                                newCollectionName = ""
                                showNewCollectionField = false
                            }
                            .disabled(newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button {
                            showNewCollectionField = true
                        } label: {
                            Label("Nouvelle collection", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Ajouter à…")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ajouter") {
                        onConfirm(Array(selected))
                        dismiss()
                    }
                    .buttonStyle(.bdPrimary)
                }
            }
            .onAppear {
                // Pré-sélectionne la suggestion la plus pertinente, l'utilisateur peut désélectionner.
                if let top = suggested.first {
                    selected.insert(top.id)
                }
            }
        }
    }

    private func collectionRow(_ collection: BookCollection) -> some View {
        Button {
            if selected.contains(collection.id) {
                selected.remove(collection.id)
            } else {
                selected.insert(collection.id)
            }
        } label: {
            HStack {
                Text(collection.name).foregroundColor(BDTheme.text)
                Spacer()
                if selected.contains(collection.id) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(BDTheme.accent)
                } else {
                    Image(systemName: "circle").foregroundColor(BDTheme.text3)
                }
            }
        }
    }

    private var metaLine: String? {
        let parts = [result.series, result.author, result.year.map(String.init)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
