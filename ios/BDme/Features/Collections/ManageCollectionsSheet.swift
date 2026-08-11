import SwiftUI

/// Gestion des collections perso : créer, renommer, supprimer.
struct ManageCollectionsSheet: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var renaming: BookCollection?
    @State private var renameText = ""
    @State private var pendingDelete: BookCollection?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Nouvelle collection…", text: $newName)
                        Button("Créer") {
                            let trimmed = newName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            library.createCollection(name: trimmed)
                            newName = ""
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    if library.collections.isEmpty {
                        Text("Aucune collection pour l'instant.")
                            .font(BDTheme.sans(13.5))
                            .foregroundColor(BDTheme.text3)
                    } else {
                        ForEach(library.collections) { collection in
                            HStack {
                                if renaming?.id == collection.id {
                                    TextField("Nom", text: $renameText, onCommit: {
                                        library.renameCollection(collection, to: renameText.trimmingCharacters(in: .whitespaces))
                                        renaming = nil
                                    })
                                } else {
                                    Text(collection.name).foregroundColor(BDTheme.text)
                                    Spacer()
                                    Text("\(library.books(in: collection).count)")
                                        .font(BDTheme.sans(12))
                                        .foregroundColor(BDTheme.text3)
                                    Button {
                                        renameText = collection.name
                                        renaming = collection
                                    } label: {
                                        Image(systemName: "pencil").foregroundColor(BDTheme.text3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDelete = collection
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mes collections")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .alert(item: $pendingDelete) { collection in
                Alert(
                    title: Text("Supprimer « \(collection.name) » ?"),
                    message: Text("Les \(library.books(in: collection).count) albums qu'elle contient resteront dans votre bibliothèque."),
                    primaryButton: .destructive(Text("Supprimer")) {
                        library.deleteCollection(collection)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}
