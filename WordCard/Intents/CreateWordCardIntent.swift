#if !os(tvOS)
import AppIntents
import SwiftData

private struct CreateCardError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

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

    @Parameter(title: "Text", description: "The text content for the card",
               requestValueDialog: "What text should the card say?")
    var text: String

    @Parameter(title: "Category", description: "The card category", default: .idea)
    var category: CardCategoryAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Create a \(\.$category) card saying \(\.$text)")
    }

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw CreateCardError("Text cannot be empty.")
        }

        let cardCategory = category.toCardCategory

        let card = WordCard(
            text: trimmedText,
            category: cardCategory
        )

        let context = SharedModelContainer.container.mainContext
        context.insert(card)
        try context.save()

        return .result(value: trimmedText)
    }
}
#endif
