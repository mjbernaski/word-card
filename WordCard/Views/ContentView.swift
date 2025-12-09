import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditor = false
    @State private var selectedCard: WordCard?

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            CardListView(selectedCard: $selectedCard, showingEditor: $showingEditor)
                .navigationSplitViewColumnWidth(min: 200, ideal: 280)
        } detail: {
            if let card = selectedCard {
                CardDetailView(card: card)
            } else {
                Text("Select a card")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingEditor) {
            CardEditorView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newCard)) { _ in
            showingEditor = true
        }
        #else
        NavigationStack {
            CardListView(selectedCard: $selectedCard, showingEditor: $showingEditor)
                .sheet(isPresented: $showingEditor) {
                    NavigationStack {
                        CardEditorView()
                    }
                }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WordCard.self, inMemory: true)
}
