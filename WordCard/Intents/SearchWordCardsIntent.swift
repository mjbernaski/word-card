#if !os(tvOS)
import AppIntents
import SwiftData

private struct SearchCardsError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

struct SearchWordCardsIntent: AppIntent {

    static var title: LocalizedStringResource = "Search WordCards"

    static var description: IntentDescription = IntentDescription(
        "Searches non-archived word cards for ones whose text contains the query (case-insensitive).",
        categoryName: "Cards"
    )

    @Parameter(title: "Query", description: "Substring to search for in card text",
               requestValueDialog: "What should I search for?")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search WordCards for \(\.$query)")
    }

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SearchCardsError("Query cannot be empty.")
        }

        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor<WordCard>(
            predicate: #Predicate { $0.isArchived == false }
        )
        let cards = try context.fetch(descriptor)

        let needle = trimmed.lowercased()
        let matches = cards
            .filter { $0.text.lowercased().contains(needle) }
            .sorted { $0.createdAt > $1.createdAt }

        let output = matches.map { $0.text }.joined(separator: "\n")
        return .result(value: output)
    }
}
#endif
