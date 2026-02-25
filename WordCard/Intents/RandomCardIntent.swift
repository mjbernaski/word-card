#if !os(tvOS)
import AppIntents
import SwiftData
import CoreGraphics

private struct RandomCardError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

struct RandomCardIntent: AppIntent {

    static var title: LocalizedStringResource = "Random WordCard"

    static var description: IntentDescription = IntentDescription(
        "Picks a random non-archived word card and returns it as a PNG image.",
        categoryName: "Cards"
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Get a random WordCard as PNG")
    }

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor<WordCard>(
            predicate: #Predicate { $0.isArchived == false }
        )
        let cards = try context.fetch(descriptor)

        guard let card = cards.randomElement() else {
            throw RandomCardError("No cards available.")
        }

        let exporter = PNGExporter()
        guard let image = exporter.export(card: card, resolution: .medium) else {
            throw RandomCardError("Failed to render card image.")
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try exporter.saveToPNG(image: image, url: tempURL)
        let data = try Data(contentsOf: tempURL)
        try FileManager.default.removeItem(at: tempURL)

        let file = IntentFile(data: data, filename: "wordcard.png", type: .png)
        return .result(value: file)
    }
}
#endif
