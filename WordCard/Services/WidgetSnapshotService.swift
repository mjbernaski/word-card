import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetCardSnapshot: Codable {
    let id: UUID
    let text: String
    let backgroundColorHex: String
    let textColorHex: String
    let fontName: String
    let cornerRadius: Int
    let borderColorHex: String?
    let borderWidth: Int
    let notes: String
}

struct WidgetCardsSnapshot: Codable {
    let cards: [WidgetCardSnapshot]
    let generatedAt: Date
}

enum WidgetSnapshotService {
    static let appGroupIdentifier = "group.mjbernaski.wordcard.app"
    static let snapshotFileName = "widget-cards.json"
    static let widgetKind = "WordCardWidget"
    static let maxSnapshotCards = 500

    static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(snapshotFileName)
    }

    @MainActor
    static func refresh(from container: ModelContainer) {
        guard let url = snapshotURL else {
            print("⚠️ Widget snapshot skipped: App Group container not available")
            return
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WordCard>()

        let cards = ((try? context.fetch(descriptor)) ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }

        guard !cards.isEmpty else {
            writeEmptySnapshot(to: url)
            reloadWidgetTimelines()
            return
        }

        let trimmed = Array(cards.prefix(maxSnapshotCards))
        let snapshot = WidgetCardsSnapshot(
            cards: trimmed.map { card in
                WidgetCardSnapshot(
                    id: card.id,
                    text: card.text,
                    backgroundColorHex: card.backgroundColor,
                    textColorHex: card.textColor,
                    fontName: card.fontStyle.fontName,
                    cornerRadius: card.cornerRadius,
                    borderColorHex: card.borderColor,
                    borderWidth: card.borderWidth,
                    notes: card.notes
                )
            },
            generatedAt: Date()
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
            reloadWidgetTimelines()
        } catch {
            print("⚠️ Failed to write widget snapshot: \(error)")
        }
    }

    private static func writeEmptySnapshot(to url: URL) {
        let empty = WidgetCardsSnapshot(cards: [], generatedAt: Date())
        if let data = try? JSONEncoder().encode(empty) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func reloadWidgetTimelines() {
        #if canImport(WidgetKit) && !os(tvOS)
        if #available(visionOS 26.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
        #endif
    }
}
