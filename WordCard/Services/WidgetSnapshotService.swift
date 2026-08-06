import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetCardSnapshot: Codable, Sendable {
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

struct WidgetCardsSnapshot: Codable, Sendable {
    let cards: [WidgetCardSnapshot]
    let generatedAt: Date
}

enum WidgetSnapshotService {
    static let appGroupIdentifier = "group.mjbernaski.wordcard.app"
    static let snapshotFileName = "widget-cards.json"
    static let widgetKind = "WordCardWidget"
    static let maxSnapshotCards = 500
    @MainActor private static var lastRefreshStartedAt: Date?

    static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(snapshotFileName)
    }

    @MainActor
    static func refresh(cards: [WordCard]) async {
        let now = Date()
        if let lastRefreshStartedAt,
           now.timeIntervalSince(lastRefreshStartedAt) < 3 {
            return
        }
        lastRefreshStartedAt = now

        guard let url = snapshotURL else {
            print("⚠️ Widget snapshot skipped: App Group container not available")
            return
        }

        let snapshotCards = cards
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(maxSnapshotCards)
            .map { card in
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
            }

        let snapshot = WidgetCardsSnapshot(
            cards: snapshotCards,
            generatedAt: Date()
        )

        let didWrite = await Task.detached(priority: .utility) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
                return true
            } catch {
                print("⚠️ Failed to write widget snapshot: \(error)")
                return false
            }
        }.value

        if didWrite {
            reloadWidgetTimelines()
        }
    }

    private static func reloadWidgetTimelines() {
        #if canImport(WidgetKit) && !os(tvOS)
        if #available(iOS 17.0, macOS 14.0, visionOS 1.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
        #endif
    }
}
