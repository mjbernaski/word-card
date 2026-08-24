import SwiftUI
import SwiftData

/// Total and archived card counts.
///
/// The archived figure is not a detail: the list view hides archived cards, so
/// the visible count and the store's real count disagree by design. Showing
/// both means a card that "vanished" is accounted for rather than mysterious.
struct ImageCardCountBadge: View {
    @Query private var allImageCards: [ImageCard]

    private var total: Int { allImageCards.count }
    private var archived: Int { allImageCards.count(where: { $0.isArchived }) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.stack")
            Text("\(total)")
                .monospacedDigit()

            if archived > 0 {
                Text("·")
                    .foregroundStyle(.secondary)
                Image(systemName: "archivebox")
                    .foregroundStyle(.secondary)
                Text("\(archived)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            archived > 0
                ? "\(total) image cards, \(archived) archived"
                : "\(total) image cards"
        )
        .help(
            archived > 0
                ? "\(total) cards in total, \(archived) of them archived"
                : "\(total) cards"
        )
    }
}

#Preview {
    ImageCardCountBadge()
        .modelContainer(for: ImageCard.self, inMemory: true)
}
