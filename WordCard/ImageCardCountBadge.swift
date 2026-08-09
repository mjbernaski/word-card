import SwiftUI
import SwiftData

struct ImageCardCountBadge: View {
    @Query private var allImageCards: [ImageCard]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.stack")
            Text("\(allImageCards.count)")
                .monospacedDigit()
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityLabel("Total image cards: \(allImageCards.count)")
    }
}

#Preview {
    ImageCardCountBadge()
        .modelContainer(for: ImageCard.self, inMemory: true)
}
