import SwiftUI
import SwiftData

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordCard.updatedAt, order: .reverse) private var cards: [WordCard]
    @Binding var selectedCard: WordCard?
    @Binding var showingEditor: Bool
    @State private var searchText = ""

    private var filteredCards: [WordCard] {
        if searchText.isEmpty {
            return cards
        }
        return cards.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                gridView
            } else {
                listView
            }
            #else
            gridView
            #endif
        }
        .navigationTitle("Word Cards")
        .searchable(text: $searchText, prompt: "Search cards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
            }
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300))], spacing: 16) {
                ForEach(filteredCards) { card in
                    CardThumbnailView(card: card)
                        .onTapGesture {
                            selectedCard = card
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteCard(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
        .overlay {
            if filteredCards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Tap + to create your first word card")
                }
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredCards) { card in
                NavigationLink(value: card) {
                    HStack {
                        CardThumbnailView(card: card)
                            .frame(width: 120, height: 60)
                        Text(card.text)
                            .lineLimit(2)
                    }
                }
            }
            .onDelete(perform: deleteCards)
        }
        .navigationDestination(for: WordCard.self) { card in
            CardDetailView(card: card)
        }
        .overlay {
            if filteredCards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Tap + to create your first word card")
                }
            }
        }
    }

    private func deleteCard(_ card: WordCard) {
        withAnimation {
            modelContext.delete(card)
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredCards[index])
            }
        }
    }
}

struct CardThumbnailView: View {
    let card: WordCard

    var body: some View {
        CardPreviewView(
            text: card.text,
            backgroundColor: Color(hex: card.backgroundColor) ?? .white,
            textColor: Color(hex: card.textColor) ?? .black,
            fontStyle: card.fontStyle,
            cornerRadius: CGFloat(card.cornerRadius),
            borderColor: card.borderColor.flatMap { Color(hex: $0) },
            borderWidth: CGFloat(card.borderWidth)
        )
        .aspectRatio(2, contentMode: .fit)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        CardListView(selectedCard: .constant(nil), showingEditor: .constant(false))
    }
    .modelContainer(for: WordCard.self, inMemory: true)
}
