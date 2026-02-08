import AppIntents
import SwiftData

enum CardCategoryAppEnum: String, AppEnum {
    case idea
    case readings
    case miscellaneous

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Category"
    }

    static var caseDisplayRepresentations: [CardCategoryAppEnum: DisplayRepresentation] {
        [
            .idea: DisplayRepresentation(title: "Idea"),
            .readings: DisplayRepresentation(title: "Readings"),
            .miscellaneous: DisplayRepresentation(title: "Miscellaneous")
        ]
    }

    var toCardCategory: CardCategory {
        switch self {
        case .idea: return .idea
        case .readings: return .readings
        case .miscellaneous: return .miscellaneous
        }
    }
}

struct CreateWordCardIntent: AppIntent {

    static var title: LocalizedStringResource = "Create a WordCard"

    static var description: IntentDescription = IntentDescription(
        "Creates a new word card with the given text and category.",
        categoryName: "Cards"
    )

    @Parameter(title: "Text", description: "The text content for the card")
    var text: String

    @Parameter(title: "Category", description: "The card category", default: .idea)
    var category: CardCategoryAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Create a \(\.$category) card saying \(\.$text)")
    }

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw $text.needsValueError("What text should the card say?")
        }

        let cardCategory = category.toCardCategory

        let card = WordCard(
            text: trimmedText,
            category: cardCategory
        )

        let context = SharedModelContainer.container.mainContext
        context.insert(card)
        try context.save()

        try await Task.sleep(for: .seconds(2))

        return .result(
            dialog: "Created a new \(cardCategory.displayName) card."
        )
    }
}
