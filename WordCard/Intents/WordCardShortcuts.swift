#if !os(tvOS)
import AppIntents

struct WordCardShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateWordCardIntent(),
            phrases: [
                "Create a WordCard in \(.applicationName)",
                "Create a new word card in \(.applicationName)",
                "Add a WordCard in \(.applicationName)",
                "New WordCard in \(.applicationName)",
                "Make a WordCard in \(.applicationName)"
            ],
            shortTitle: "Create Card",
            systemImageName: "plus.rectangle.on.rectangle"
        )
        AppShortcut(
            intent: RandomCardIntent(),
            phrases: [
                "Show me a random WordCard in \(.applicationName)",
                "Show me a random word card in \(.applicationName)",
                "Random WordCard from \(.applicationName)",
                "Read me a WordCard in \(.applicationName)"
            ],
            shortTitle: "Random Card",
            systemImageName: "die.face.5"
        )
        AppShortcut(
            intent: ReadWordCardsIntent(),
            phrases: [
                "Read me WordCards in \(.applicationName)",
                "Read my WordCards in \(.applicationName)",
                "Read me some word cards in \(.applicationName)",
                "Read WordCards from \(.applicationName)"
            ],
            shortTitle: "Read Cards",
            systemImageName: "text.book.closed"
        )
        AppShortcut(
            intent: SearchWordCardsIntent(),
            phrases: [
                "Search WordCards in \(.applicationName)",
                "Search my word cards in \(.applicationName)",
                "Find WordCards in \(.applicationName)",
                "Find a WordCard in \(.applicationName)"
            ],
            shortTitle: "Search Cards",
            systemImageName: "magnifyingglass"
        )
    }
}
#endif
