import Foundation
import SwiftUI

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
    /// Optional so a snapshot written by an older build still decodes.
    let isItalic: Bool?
}

struct WidgetCardsSnapshot: Codable {
    let cards: [WidgetCardSnapshot]
    let generatedAt: Date
}

enum WidgetSharedConstants {
    static let appGroupIdentifier = "group.mjbernaski.wordcard.app"
    static let snapshotFileName = "widget-cards.json"
    static let widgetKind = "WordCardWidget"
}

enum WidgetSnapshotReader {
    static func loadSnapshot() -> WidgetCardsSnapshot? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSharedConstants.appGroupIdentifier)?
            .appendingPathComponent(WidgetSharedConstants.snapshotFileName)
        else { return nil }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetCardsSnapshot.self, from: data)
    }

    static func randomCard() -> WidgetCardSnapshot? {
        loadSnapshot()?.cards.randomElement()
    }
}

extension Color {
    init?(widgetHex hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        switch hexSanitized.count {
        case 6:
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8:
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        default:
            return nil
        }
    }
}
