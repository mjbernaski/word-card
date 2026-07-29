#if !os(tvOS)
import AppIntents
import SwiftData
import SwiftUI

private struct ReadCardsError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

struct ReadWordCardsIntent: AppIntent {

    static let title: LocalizedStringResource = "Read WordCards"

    static let description: IntentDescription = IntentDescription(
        "Reads several of your cards aloud and shows them.",
        categoryName: "Cards",
        resultValueName: "WordCards"
    )

    @Parameter(
        title: "Number of Cards",
        description: "How many cards to read",
        default: 5,
        inclusiveRange: (1, 20)
    )
    var count: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Read \(\.$count) WordCards")
    }

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[WordCardEntity]> & ProvidesDialog & ShowsSnippetView {
        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor<WordCard>()
        let allCards = try context.fetch(descriptor)
            .filter { !$0.isArchived }

        guard !allCards.isEmpty else {
            throw ReadCardsError("You don't have any cards yet.")
        }

        let selected = Array(allCards.shuffled().prefix(count))
        let entities = selected.map(WordCardEntity.init)

        // Build the spoken text: pause between cards for a natural reading.
        let spoken = selected
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")

        let dialog: IntentDialog = entities.count == 1
            ? "\(spoken)"
            : "Here are \(entities.count) cards. \(spoken)"

        return .result(
            value: entities,
            dialog: dialog,
            view: WordCardsSnippetView(cards: Array(entities.prefix(6)))
        )
    }
}
#endif
