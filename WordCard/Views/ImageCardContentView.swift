import SwiftUI
import SwiftData

struct ImageCardContentView: View {
    @State private var showingEditor = false
    @State private var selectedImageCard: ImageCard?

    #if os(macOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif

    var body: some View {
        #if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ImageCardListView(selectedCard: $selectedImageCard, showingEditor: $showingEditor)
                .navigationSplitViewColumnWidth(min: 300, ideal: 380)
        } detail: {
            if let card = selectedImageCard {
                ImageCardDetailView(card: card)
            } else {
                ContentUnavailableView {
                    Label("Select an Image Card", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Select a card from the list or paste an image from your clipboard (Cmd+V)")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                ImageCardEditorView()
            }
            .frame(minWidth: 520, minHeight: 620)
        }
        #elseif os(visionOS)
        NavigationSplitView {
            ImageCardListView(selectedCard: $selectedImageCard, showingEditor: $showingEditor)
        } detail: {
            if let card = selectedImageCard {
                ImageCardDetailView(card: card)
            } else {
                ContentUnavailableView {
                    Label("Select an Image Card", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Select an image card to inspect")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                ImageCardEditorView()
            }
        }
        #else
        NavigationStack {
            ImageCardListView(selectedCard: $selectedImageCard, showingEditor: $showingEditor)
                .navigationDestination(item: $selectedImageCard) { card in
                    ImageCardDetailView(card: card)
                }
                .sheet(isPresented: $showingEditor) {
                    NavigationStack {
                        ImageCardEditorView()
                    }
                }
        }
        #endif
    }
}
