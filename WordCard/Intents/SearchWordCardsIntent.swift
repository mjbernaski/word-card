#if !os(tvOS)
import AppIntents
import SwiftData
import SwiftUI

private struct SearchCardsError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

struct SearchWordCardsIntent: AppIntent {

    static let title: LocalizedStringResource = "Search WordCards"

    static let description: IntentDescription = IntentDescription(
        "Searches non-archived word cards for ones whose text contains the query (case-insensitive).",
        categoryName: "Cards",
        resultValueName: "Matching WordCards"
    )

    @Parameter(title: "Query", description: "Substring to search for in card text",
               requestValueDialog: "What should I search for?")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search WordCards for \(\.$query)")
    }

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[WordCardEntity]> & ProvidesDialog & ShowsSnippetView {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SearchCardsError("Query cannot be empty.")
        }

        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor<WordCard>()
        let cards = try context.fetch(descriptor)
            .filter { !$0.isArchived }

        let needle = trimmed.lowercased()
        let matches = cards
            .filter { $0.text.lowercased().contains(needle) }
            .sorted { $0.createdAt > $1.createdAt }
            .map(WordCardEntity.init)

        guard !matches.isEmpty else {
            return .result(
                value: [],
                dialog: "I couldn't find any cards matching \(trimmed).",
                view: EmptyView()
            )
        }

        let dialog: IntentDialog = matches.count == 1
            ? "I found one card matching \(trimmed)."
            : "I found \(matches.count) cards matching \(trimmed)."

        return .result(
            value: matches,
            dialog: dialog,
            view: WordCardsSnippetView(cards: Array(matches.prefix(6)))
        )
    }
}
#endif
