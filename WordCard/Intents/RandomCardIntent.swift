#if !os(tvOS)
import AppIntents
import SwiftData

private struct RandomCardError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

struct RandomCardIntent: AppIntent {

    static let title: LocalizedStringResource = "Show a Random WordCard"

    static let description: IntentDescription = IntentDescription(
        "Picks a random card, reads it aloud, and shows it.",
        categoryName: "Cards",
        resultValueName: "Random WordCard"
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Show a random WordCard")
    }

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<WordCardEntity> & ProvidesDialog & ShowsSnippetView {
        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor<WordCard>()
        let cards = try context.fetch(descriptor)
            .filter { !$0.isArchived }

        guard let card = cards.randomElement() else {
            throw RandomCardError("You don't have any cards yet.")
        }

        let entity = WordCardEntity(card: card)
        return .result(
            value: entity,
            dialog: "\(card.text)",
            view: WordCardSnippetView(card: entity)
        )
    }
}
#endif
