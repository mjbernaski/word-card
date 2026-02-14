#if os(tvOS)
import SwiftUI
import SwiftData

struct CardShowcaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<WordCard> { !$0.isArchived },
           sort: \WordCard.createdAt)
    private var cards: [WordCard]

    private let stages = [1, 2, 4, 8, 12, 16]
    @State private var stageIndex = 0
    @State private var timer: Timer?

    private var currentCount: Int {
        let stage = stages[stageIndex]
        return min(stage, cards.count)
    }

    private var displayedCards: [WordCard] {
        Array(cards.prefix(currentCount))
    }

    private var columnCount: Int {
        switch currentCount {
        case 1: return 1
        case 2: return 2
        case 3...4: return 2
        case 5...8: return 4
        case 9...12: return 4
        default: return 4
        }
    }

    private var maxStageIndex: Int {
        guard !cards.isEmpty else { return 0 }
        for i in stride(from: stages.count - 1, through: 0, by: -1) {
            if stages[i] <= cards.count {
                return i
            }
        }
        return 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding()
                    Spacer()
                }

                Spacer()

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: columnCount),
                    spacing: 24
                ) {
                    ForEach(displayedCards) { card in
                        CardThumbnailView(card: card)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, currentCount == 1 ? 200 : 40)

                Spacer()

                Text("\(currentCount) card\(currentCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onExitCommand {
            dismiss()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            advanceStage()
        }
    }

    private func advanceStage() {
        withAnimation(.spring(duration: 0.6)) {
            let maxIdx = maxStageIndex
            if stageIndex >= maxIdx {
                stageIndex = 0
            } else {
                stageIndex += 1
            }
        }
    }
}
#endif
