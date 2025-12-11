import SwiftUI
import SwiftData

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WordCard> { !$0.isArchived }, sort: \WordCard.updatedAt, order: .reverse) private var cards: [WordCard]
    @Binding var selectedCard: WordCard?
    @Binding var showingEditor: Bool
    @State private var searchText = ""
    @State private var showingArchive = false

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
        .navigationTitle("Cards")
        .searchable(text: $searchText, prompt: "Search cards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingArchive = true
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }
        }
        .sheet(isPresented: $showingArchive) {
            ArchiveView()
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
                                archiveCard(card)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
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
                    Text("Tap + to create your first card")
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
            .onDelete(perform: archiveCards)
        }
        .navigationDestination(for: WordCard.self) { card in
            CardDetailView(card: card)
        }
        .overlay {
            if filteredCards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Tap + to create your first card")
                }
            }
        }
    }

    private func archiveCard(_ card: WordCard) {
        withAnimation {
            card.archive()
        }
    }

    private func archiveCards(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                filteredCards[index].archive()
            }
        }
    }
}

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<WordCard> { $0.isArchived }, sort: \WordCard.archivedAt, order: .reverse) private var archivedCards: [WordCard]

    var body: some View {
        NavigationStack {
            List {
                if archivedCards.isEmpty {
                    ContentUnavailableView {
                        Label("No Archived Cards", systemImage: "archivebox")
                    } description: {
                        Text("Cards you archive will appear here")
                    }
                } else {
                    ForEach(archivedCards) { card in
                        HStack {
                            CardThumbnailView(card: card)
                                .frame(width: 120, height: 60)
                            VStack(alignment: .leading) {
                                Text(card.text)
                                    .lineLimit(2)
                                if let archivedAt = card.archivedAt {
                                    Text("Archived \(archivedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                card.restore()
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                        .contextMenu {
                            Button {
                                card.restore()
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(card)
                            } label: {
                                Label("Delete Permanently", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Archive")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
