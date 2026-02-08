import AppIntents

struct WordCardShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateWordCardIntent(),
            phrases: [
                "Create a WordCard in \(.applicationName)",
                "Add a WordCard in \(.applicationName)",
                "New WordCard in \(.applicationName)",
                "Make a WordCard in \(.applicationName)"
            ],
            shortTitle: "Create Card",
            systemImageName: "plus.rectangle.on.rectangle"
        )
    }
}
