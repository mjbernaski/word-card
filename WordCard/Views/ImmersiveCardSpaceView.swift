#if os(visionOS)
import SwiftUI
import SwiftData

struct ImmersiveCardSpaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: ImmersiveCardSpaceView.activeCardsPredicate, sort: [
        SortDescriptor(\WordCard.updatedAt, order: .reverse),
        SortDescriptor(\WordCard.createdAt, order: .reverse)
    ]) private var cards: [WordCard]

    private static let activeCardsPredicate = #Predicate<WordCard> { card in
        card.isArchived == false
    }

    @State private var currentCardIndex: Int = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 3D card carousel using SwiftUI transforms
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CardView3D(card: card, index: index, currentIndex: currentCardIndex)
                }

                // Navigation overlay
                VStack {
                    Spacer()

                    HStack(spacing: 40) {
                        Button {
                            withAnimation(.spring(duration: 0.4)) {
                                currentCardIndex = max(0, currentCardIndex - 1)
                            }
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 44))
                        }
                        .disabled(currentCardIndex <= 0)

                        Text("\(currentCardIndex + 1) of \(cards.count)")
                            .font(.title2)
                            .monospacedDigit()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())

                        Button {
                            withAnimation(.spring(duration: 0.4)) {
                                currentCardIndex = min(cards.count - 1, currentCardIndex + 1)
                            }
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 44))
                        }
                        .disabled(currentCardIndex >= cards.count - 1)
                    }
                    .padding(.bottom, 60)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black.opacity(0.3))
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    withAnimation(.spring(duration: 0.4)) {
                        if value.translation.width < -threshold {
                            currentCardIndex = min(cards.count - 1, currentCardIndex + 1)
                        } else if value.translation.width > threshold {
                            currentCardIndex = max(0, currentCardIndex - 1)
                        }
                    }
                }
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                }
            }
        }
        .navigationTitle("Card Space")
    }
}

struct CardView3D: View {
    let card: WordCard
    let index: Int
    let currentIndex: Int

    private var relativeIndex: Int {
        index - currentIndex
    }

    var body: some View {
        // Card styling
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(hex: card.backgroundColor) ?? .white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(hex: card.borderColor ?? "#CC785C") ?? .brown, lineWidth: CGFloat(card.borderWidth))
            )
            .overlay(
                Text(card.text)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: card.textColor) ?? .black)
                    .multilineTextAlignment(.center)
                    .padding(24)
            )
            .frame(width: 400, height: 200)
            .rotation3DEffect(
                .degrees(Double(relativeIndex) * 8),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .offset(x: CGFloat(relativeIndex) * 60)
            .scaleEffect(relativeIndex == 0 ? 1.0 : max(0.7, 1.0 - Double(abs(relativeIndex)) * 0.1))
            .opacity(abs(relativeIndex) > 5 ? 0 : 1.0 - Double(abs(relativeIndex)) * 0.15)
            .zIndex(Double(-abs(relativeIndex)))
            .animation(.spring(duration: 0.4), value: currentIndex)
    }
}

#Preview {
    ImmersiveCardSpaceView()
        .modelContainer(for: WordCard.self, inMemory: true)
}
#endif

