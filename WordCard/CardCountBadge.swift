import SwiftUI
import SwiftData

struct CardCountBadge: View {
    @Query private var allCards: [WordCard]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.stack")
            Text("\(allCards.count)")
                .monospacedDigit()
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .accessibilityLabel("Total cards: \(allCards.count)")
    }
}

#Preview {
    CardCountBadge()
        .modelContainer(for: WordCard.self, inMemory: true)
}
