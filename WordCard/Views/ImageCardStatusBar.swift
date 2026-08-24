import SwiftUI
import SwiftData

/// Footer showing how many cards exist and what CloudKit is doing about them.
///
/// It lives in ImageCardListView, which every platform branch of
/// ImageCardContentView uses, so the same bar appears on macOS, iOS and
/// visionOS without per-platform placement.
struct ImageCardStatusBar: View {
    private var status: ImageCardSyncStatus { ImageCardSyncStatus.shared }

    var body: some View {
        HStack(spacing: 10) {
            ImageCardCountBadge()

            Spacer(minLength: 8)

            syncIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    @ViewBuilder
    private var syncIndicator: some View {
        HStack(spacing: 6) {
            if let error = status.lastError {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.red)
                Text("Sync failed")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Sync failed: \(error)")
                    .help(error)
            } else if status.activity == .idle {
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.secondary)
                Text(idleLabel)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
                Text(status.activity.label)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .animation(.default, value: status.activity)
    }

    /// Once synced, the useful fact is when — "Synced" alone can't be told apart
    /// from a session that has never successfully talked to CloudKit at all.
    private var idleLabel: String {
        guard let last = status.lastSuccess else { return "Not synced yet" }
        return "Synced \(last.formatted(.relative(presentation: .named)))"
    }
}

#Preview {
    ImageCardStatusBar()
        .modelContainer(for: ImageCard.self, inMemory: true)
}
