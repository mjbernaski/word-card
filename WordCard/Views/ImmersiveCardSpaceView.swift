#if os(visionOS)
import SwiftUI
import SwiftData

enum Spatial3DMode: String, CaseIterable, Identifiable {
    case curvedArc = "Curved Arc"
    case orbit = "3D Orbit"
    case depthStack = "Depth Stack"

    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .curvedArc: return "rectangle.3.group"
        case .orbit: return "globe"
        case .depthStack: return "square.stack.3d.forward.fill"
        }
    }
}

struct ImmersiveCardSpaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [WordCard]

    private var cards: [WordCard] {
        allCards
            .filter { !$0.isArchived }
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.createdAt > $1.createdAt
            }
    }

    @State private var currentCardIndex: Int = 0
    @State private var spatialMode: Spatial3DMode = .curvedArc
    @State private var isInspecting: Bool = false
    @State private var isFlipped: Bool = false
    @State private var dragRotation: CGSize = .zero
    @State private var autoOrbitAngle: Double = 0

    private var currentCard: WordCard? {
        guard !cards.isEmpty, currentCardIndex < cards.count else { return nil }
        return cards[currentCardIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Ambient background aura matching active card valence
                if let card = currentCard {
                    ValenceAuraView(valence: card.valence)
                        .ignoresSafeArea()
                }

                // 3D Spatial Canvas
                ZStack {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        SpatialCard3DView(
                            card: card,
                            index: index,
                            currentIndex: currentCardIndex,
                            mode: spatialMode,
                            isInspecting: isInspecting && index == currentCardIndex,
                            isFlipped: isFlipped && index == currentCardIndex,
                            autoOrbitAngle: autoOrbitAngle,
                            dragRotation: dragRotation
                        )
                        .onTapGesture {
                            if index == currentCardIndex {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                    isInspecting.toggle()
                                    if !isInspecting { isFlipped = false }
                                }
                            } else {
                                withAnimation(.spring(duration: 0.4)) {
                                    currentCardIndex = index
                                    isInspecting = false
                                    isFlipped = false
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Floating visionOS Spatial Controls
                VStack {
                    // Top mode bar
                    HStack {
                        Spacer()
                        Picker("Spatial Mode", selection: $spatialMode) {
                            ForEach(Spatial3DMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 360)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10)
                        Spacer()
                    }
                    .padding(.top, 24)

                    Spacer()

                    // Bottom navigation and inspection bar
                    VStack(spacing: 12) {
                        if isInspecting, let card = currentCard {
                            Button {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                    isFlipped.toggle()
                                }
                            } label: {
                                Label(isFlipped ? "Show Front" : "Flip for Notes", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .hoverEffect()
                        }

                        HStack(spacing: 24) {
                            Button {
                                navigateCard(delta: -1)
                            } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 40))
                            }
                            .buttonStyle(.plain)
                            .hoverEffect()
                            .disabled(currentCardIndex <= 0)

                            Text("\(cards.isEmpty ? 0 : currentCardIndex + 1) of \(cards.count)")
                                .font(.title3.weight(.medium))
                                .monospacedDigit()
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())

                            Button {
                                navigateCard(delta: 1)
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 40))
                            }
                            .buttonStyle(.plain)
                            .hoverEffect()
                            .disabled(currentCardIndex >= cards.count - 1)
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragRotation = CGSize(
                        width: gesture.translation.width * 0.15,
                        height: gesture.translation.height * 0.15
                    )
                }
                .onEnded { gesture in
                    let threshold: CGFloat = 80
                    if gesture.translation.width < -threshold {
                        navigateCard(delta: 1)
                    } else if gesture.translation.width > threshold {
                        navigateCard(delta: -1)
                    }
                    withAnimation(.spring(duration: 0.5)) {
                        dragRotation = .zero
                    }
                }
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                }
                .hoverEffect()
            }
        }
        .navigationTitle("3D Card Space")
    }

    private func navigateCard(delta: Int) {
        guard !cards.isEmpty else { return }
        withAnimation(.spring(duration: 0.45)) {
            currentCardIndex = min(max(0, currentCardIndex + delta), cards.count - 1)
            isInspecting = false
            isFlipped = false
        }
    }
}

// MARK: - 3D Card View Transformation
struct SpatialCard3DView: View {
    let card: WordCard
    let index: Int
    let currentIndex: Int
    let mode: Spatial3DMode
    let isInspecting: Bool
    let isFlipped: Bool
    let autoOrbitAngle: Double
    let dragRotation: CGSize

    private var relativeIndex: Int {
        index - currentIndex
    }

    var body: some View {
        ZStack {
            if isFlipped {
                CardBackView(card: card)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                CardPreviewView(
                    text: card.text,
                    backgroundColor: Color(hex: card.backgroundColor) ?? .white,
                    textColor: Color(hex: card.textColor) ?? .black,
                    fontStyle: card.fontStyle,
                    cornerRadius: CGFloat(card.cornerRadius),
                    borderColor: card.borderColor.flatMap { Color(hex: $0) },
                    borderWidth: CGFloat(card.borderWidth),
                    notes: card.notes,
                    isItalic: card.isItalic
                )
            }
        }
        .frame(width: 460, height: 230)
        .shadow(color: auraColor.opacity(relativeIndex == 0 ? 0.45 : 0.15), radius: relativeIndex == 0 ? 20 : 8, x: 0, y: 8)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(rotationY),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.65
        )
        .rotation3DEffect(
            .degrees(rotationX),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.65
        )
        .offset(x: offsetX, y: offsetY)
        .scaleEffect(scale)
        .opacity(opacity)
        .zIndex(Double(100 - abs(relativeIndex)))
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: currentIndex)
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: mode)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isInspecting)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isFlipped)
    }

    private var auraColor: Color {
        let val = card.valence
        if val > 0 {
            return Color.green
        } else if val < 0 {
            return Color.red
        }
        return Color(hex: card.borderColor ?? "#CC785C") ?? .orange
    }

    private var scale: CGFloat {
        if isInspecting { return 1.25 }
        switch mode {
        case .curvedArc:
            return relativeIndex == 0 ? 1.05 : max(0.65, 1.0 - CGFloat(abs(relativeIndex)) * 0.12)
        case .orbit:
            return relativeIndex == 0 ? 1.1 : max(0.6, 0.95 - CGFloat(abs(relativeIndex)) * 0.1)
        case .depthStack:
            return relativeIndex == 0 ? 1.05 : max(0.7, 1.0 - CGFloat(abs(relativeIndex)) * 0.08)
        }
    }

    private var opacity: Double {
        if abs(relativeIndex) > 5 { return 0 }
        if isInspecting && relativeIndex != 0 { return 0.15 }
        return max(0.2, 1.0 - Double(abs(relativeIndex)) * 0.18)
    }

    private var offsetX: CGFloat {
        if isInspecting { return 0 }
        switch mode {
        case .curvedArc:
            return CGFloat(relativeIndex) * 90 + CGFloat(dragRotation.width)
        case .orbit:
            let angle = Double(relativeIndex) * 0.45
            return CGFloat(sin(angle) * 320) + CGFloat(dragRotation.width)
        case .depthStack:
            return CGFloat(relativeIndex) * 25 + CGFloat(dragRotation.width)
        }
    }

    private var offsetY: CGFloat {
        if isInspecting { return -20 }
        switch mode {
        case .curvedArc:
            return CGFloat(abs(relativeIndex) * abs(relativeIndex)) * 4 + CGFloat(dragRotation.height)
        case .orbit:
            let angle = Double(relativeIndex) * 0.45
            return CGFloat(cos(angle) * 40 - 40) + CGFloat(dragRotation.height)
        case .depthStack:
            return CGFloat(relativeIndex) * -18 + CGFloat(dragRotation.height)
        }
    }

    private var rotationY: Double {
        if isInspecting { return 0 }
        switch mode {
        case .curvedArc:
            return Double(relativeIndex) * -14
        case .orbit:
            return Double(relativeIndex) * -22
        case .depthStack:
            return Double(relativeIndex) * -6
        }
    }

    private var rotationX: Double {
        if isInspecting { return 0 }
        switch mode {
        case .curvedArc:
            return Double(abs(relativeIndex)) * 3
        case .orbit:
            return 0
        case .depthStack:
            return Double(relativeIndex) * 4
        }
    }
}

// MARK: - 3D Card Back View (Notes & Metadata)
struct CardBackView: View {
    let card: WordCard

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(card.category.displayName, systemImage: card.category.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Valence: \(card.valence > 0 ? "+\(card.valence)" : "\(card.valence)")")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(card.valence > 0 ? .green : card.valence < 0 ? .red : .secondary)
            }

            Divider()

            if card.notes.isEmpty {
                Text("No additional notes added.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(card.notes)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text("Created: \(card.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Updated: \(card.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: CGFloat(card.cornerRadius))
                .fill(Color(hex: card.backgroundColor) ?? .white)
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(card.cornerRadius))
                        .strokeBorder(Color(hex: card.borderColor ?? "#CC785C") ?? .brown, lineWidth: CGFloat(card.borderWidth))
                )
        )
    }
}

// MARK: - Valence Ambient Halo / Aura
struct ValenceAuraView: View {
    let valence: Int

    private var auraColor: Color {
        if valence > 0 {
            return Color.green
        } else if valence < 0 {
            return Color.red
        }
        return Color.orange
    }

    var body: some View {
        RadialGradient(
            colors: [
                auraColor.opacity(0.25),
                auraColor.opacity(0.08),
                Color.black.opacity(0.4)
            ],
            center: .center,
            startRadius: 80,
            endRadius: 600
        )
        .animation(.easeInOut(duration: 0.8), value: valence)
    }
}

#Preview {
    ImmersiveCardSpaceView()
        .modelContainer(for: WordCard.self, inMemory: true)
}
#endif
