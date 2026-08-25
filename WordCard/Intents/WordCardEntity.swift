#if !os(tvOS)
import AppIntents
import SwiftData
import SwiftUI
import CoreSpotlight
import UniformTypeIdentifiers

/// A Word Card exposed to Siri, Spotlight, and Shortcuts so the system can
/// reference, search, and visually display individual cards.
struct WordCardEntity: IndexedEntity, Identifiable {
    let id: UUID
    let text: String
    let category: CardCategoryAppEnum
    let backgroundColorHex: String
    let textColorHex: String
    let fontStyle: FontStyle
    let cornerRadius: Int
    let borderColorHex: String?
    let borderWidth: Int
    let notes: String
    let isItalic: Bool
    let createdAt: Date
    let updatedAt: Date

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Word Card"

    var displayRepresentation: DisplayRepresentation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return DisplayRepresentation(
            title: "\(trimmed.isEmpty ? "Untitled card" : trimmed)",
            subtitle: "\(category.displayName)"
        )
    }

    static let defaultQuery = WordCardEntityQuery()

    init(card: WordCard) {
        self.id = card.id
        self.text = card.text
        self.category = CardCategoryAppEnum(card.category)
        self.backgroundColorHex = card.backgroundColor
        self.textColorHex = card.textColor
        self.fontStyle = card.fontStyle
        self.cornerRadius = card.cornerRadius
        self.borderColorHex = card.borderColor
        self.borderWidth = card.borderWidth
        self.notes = card.notes
        self.isItalic = card.isItalic
        self.createdAt = card.createdAt
        self.updatedAt = card.updatedAt
    }

    /// Rich metadata Spotlight uses when indexing the card for search.
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "Untitled card" : trimmed
        let noteText = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        attributes.title = title
        attributes.displayName = title
        attributes.contentDescription = noteText.isEmpty ? "\(title) \(category.displayName)" : "\(title) \(noteText)"
        attributes.keywords = [title, noteText, category.displayName, "word card", "word-card", "card", "Valence"]
            .filter { !$0.isEmpty }
        attributes.userCreated = true
        attributes.contentCreationDate = createdAt
        attributes.contentModificationDate = updatedAt
        return attributes
    }
}

/// Lets the system locate cards by identifier, by spoken text, and offer
/// suggestions (used by Siri parameter resolution and Shortcuts).
struct WordCardEntityQuery: EntityStringQuery {

    @MainActor
    private func fetchActiveCards() throws -> [WordCard] {
        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor<WordCard>()
        return try context.fetch(descriptor)
            .filter { !$0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @MainActor
    func entities(for identifiers: [WordCardEntity.ID]) async throws -> [WordCardEntity] {
        let wanted = Set(identifiers)
        return try fetchActiveCards()
            .filter { wanted.contains($0.id) }
            .map(WordCardEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WordCardEntity] {
        let needle = string.lowercased()
        return try fetchActiveCards()
            .filter { $0.text.lowercased().contains(needle) }
            .map(WordCardEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [WordCardEntity] {
        Array(try fetchActiveCards().prefix(10).map(WordCardEntity.init))
    }
}

/// Renders a single card for display inside a Siri / Shortcuts result snippet.
struct WordCardSnippetView: View {
    let card: WordCardEntity

    var body: some View {
        CardPreviewView(
            text: card.text,
            backgroundColor: Color(hex: card.backgroundColorHex) ?? .white,
            textColor: Color(hex: card.textColorHex) ?? .black,
            fontStyle: card.fontStyle,
            cornerRadius: CGFloat(card.cornerRadius),
            borderColor: card.borderColorHex.flatMap { Color(hex: $0) },
            borderWidth: CGFloat(card.borderWidth),
            notes: card.notes,
            isItalic: card.isItalic
        )
        .frame(maxWidth: 360)
        .padding()
    }
}

/// Renders a stack of cards for a multi-card Siri / Shortcuts result snippet.
struct WordCardsSnippetView: View {
    let cards: [WordCardEntity]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(cards) { card in
                WordCardSnippetView(card: card)
            }
        }
        .padding(.vertical)
    }
}
#endif
