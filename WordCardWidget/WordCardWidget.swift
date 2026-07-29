import WidgetKit
import SwiftUI

struct WordCardEntry: TimelineEntry {
    let date: Date
    let card: WidgetCardSnapshot?
}

struct WordCardProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordCardEntry {
        WordCardEntry(date: Date(), card: Self.placeholderCard)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordCardEntry) -> Void) {
        let card = context.isPreview
            ? Self.placeholderCard
            : (WidgetSnapshotReader.randomCard() ?? Self.placeholderCard)
        completion(WordCardEntry(date: Date(), card: card))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordCardEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let entries: [WordCardEntry] = (0..<12).map { offset in
            let date = calendar.date(byAdding: .hour, value: offset, to: now) ?? now
            return WordCardEntry(date: date, card: WidgetSnapshotReader.randomCard())
        }
        let refreshDate = calendar.date(byAdding: .hour, value: 12, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    static let placeholderCard = WidgetCardSnapshot(
        id: UUID(),
        text: "Word Card",
        backgroundColorHex: "#FFFFFF",
        textColorHex: "#000000",
        fontName: "Georgia",
        cornerRadius: 20,
        borderColorHex: "#CC785C",
        borderWidth: 1,
        notes: ""
    )
}

struct WordCardWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordCardEntry

    var body: some View {
        Group {
            if let card = entry.card {
                cardView(card)
            } else {
                emptyView
            }
        }
        .containerBackground(for: .widget) {
            if let card = entry.card,
               let bg = Color(widgetHex: card.backgroundColorHex) {
                bg
            } else {
                Color(white: 0.97)
            }
        }
    }

    @ViewBuilder
    private func cardView(_ card: WidgetCardSnapshot) -> some View {
        GeometryReader { geo in
            let textColor = Color(widgetHex: card.textColorHex) ?? .primary
            let displayText = card.text.isEmpty ? "Word Card" : card.text
            let font = Font.custom(card.fontName, size: fontSize(for: geo.size, text: displayText))

            VStack(spacing: 0) {
                Text(displayText)
                    .font(font)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.6)
                    .lineLimit(nil)

                if !card.notes.isEmpty && family != .systemSmall {
                    Spacer().frame(height: geo.size.height * 0.06)
                    Text(card.notes)
                        .font(.system(size: max(geo.size.height * 0.07, 9)))
                        .foregroundStyle(textColor.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(geo.size.width * 0.06)
        }
        .widgetURL(URL(string: "wordcard://open/\(card.id.uuidString)"))
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open Word Card to add a card")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func fontSize(for size: CGSize, text: String) -> CGFloat {
        let base = min(size.height * 0.32, size.width * 0.14)
        return max(base * lengthScale(for: text.count), 11)
    }

    private func lengthScale(for charCount: Int) -> CGFloat {
        switch charCount {
        case ...10: return 1.0
        case 11...20: return 0.85
        case 21...35: return 0.7
        default: return 0.55
        }
    }
}

struct WordCardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetSharedConstants.widgetKind,
            provider: WordCardProvider()
        ) { entry in
            WordCardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Random Word Card")
        .description("Shows a random card from your collection. Tap to open the app.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular]
        #else
        return [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

#Preview(as: .systemMedium) {
    WordCardWidget()
} timeline: {
    WordCardEntry(date: .now, card: WordCardProvider.placeholderCard)
    WordCardEntry(
        date: .now,
        card: WidgetCardSnapshot(
            id: UUID(),
            text: "amor fati",
            backgroundColorHex: "#F5DEB3",
            textColorHex: "#1A1A1A",
            fontName: "Georgia",
            cornerRadius: 20,
            borderColorHex: "#CC785C",
            borderWidth: 1,
            notes: "love of fate"
        )
    )
}
