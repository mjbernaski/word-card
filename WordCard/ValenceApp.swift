import SwiftUI
import SwiftData

@main
struct ValenceApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([WordCard.self])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.mjbernaski.wordcard.app")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("✅ SwiftData container created with CloudKit sync")
            print("📁 Database URL: \(config.url)")
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Card") {
                    NotificationCenter.default.post(name: .newCard, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif
    }
}

extension Notification.Name {
    static let newCard = Notification.Name("newCard")
}
