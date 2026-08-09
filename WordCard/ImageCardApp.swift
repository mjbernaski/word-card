import SwiftUI
import SwiftData

@main
struct ImageCardApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([ImageCard.self])
        let config = ModelConfiguration(
            "ImageCards",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create the ImageCard data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ImageCardContentView()
        }
        .modelContainer(modelContainer)
    }
}
