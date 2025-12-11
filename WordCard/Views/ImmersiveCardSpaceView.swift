#if os(visionOS)
import SwiftUI
import RealityKit
import SwiftData

struct ImmersiveCardSpaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<WordCard> { !$0.isArchived }, sort: \WordCard.updatedAt, order: .reverse) private var cards: [WordCard]

    @State private var currentCardIndex: Int = 0
    @State private var cameraOffset: SIMD3<Float> = [0, 0, 0]

    var body: some View {
        ZStack {
            RealityView { content in
                // Create anchor for the card space
                let anchor = AnchorEntity(world: [0, 1.5, -2])

                // Add cards in a 3D grid/depth arrangement
                for (index, card) in cards.enumerated() {
                    let cardEntity = createCardEntity(for: card, at: index, total: cards.count)
                    anchor.addChild(cardEntity)
                }

                content.add(anchor)
            } update: { content in
                // Update card positions based on navigation
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Move through the space
                        let translation = value.translation
                        cameraOffset.z += Float(translation.height) * 0.001
                    }
            )

            // Navigation UI overlay
            VStack {
                Spacer()

                HStack(spacing: 40) {
                    Button {
                        navigateToPreviousCard()
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
                        navigateToNextCard()
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 44))
                    }
                    .disabled(currentCardIndex >= cards.count - 1)
                }
                .padding(.bottom, 50)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white, .gray.opacity(0.5))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .navigationTitle("Card Space")
    }

    private func createCardEntity(for card: WordCard, at index: Int, total: Int) -> ModelEntity {
        // Calculate position in 3D space
        // Cards arranged in a curved path going into the distance
        let depth = Float(index) * 0.8  // Space between cards in Z
        let curve = sin(Float(index) * 0.3) * 0.5  // Slight curve left/right
        let height = cos(Float(index) * 0.2) * 0.3  // Slight wave up/down

        let position: SIMD3<Float> = [curve, height, -depth]

        // Create card mesh (3:1.5 aspect ratio like real cards)
        let cardWidth: Float = 0.4
        let cardHeight: Float = 0.2
        let cardDepth: Float = 0.005

        let mesh = MeshResource.generateBox(width: cardWidth, height: cardHeight, depth: cardDepth, cornerRadius: 0.02)

        // Create material with card colors
        var material = SimpleMaterial()
        material.color = .init(tint: uiColorFromHex(card.backgroundColor))

        let cardEntity = ModelEntity(mesh: mesh, materials: [material])
        cardEntity.position = position

        // Rotate slightly to face the viewer
        let lookAtAngle = atan2(position.x, -position.z)
        cardEntity.orientation = simd_quatf(angle: lookAtAngle * 0.3, axis: [0, 1, 0])

        // Add text as a child entity
        if let textEntity = createTextEntity(for: card, width: cardWidth, height: cardHeight) {
            textEntity.position = [0, 0, cardDepth / 2 + 0.001]
            cardEntity.addChild(textEntity)
        }

        // Enable gestures on the card
        cardEntity.components.set(InputTargetComponent())
        cardEntity.components.set(CollisionComponent(shapes: [.generateBox(width: cardWidth, height: cardHeight, depth: cardDepth)]))

        return cardEntity
    }

    private func createTextEntity(for card: WordCard, width: Float, height: Float) -> ModelEntity? {
        // Create text mesh
        let textMesh = MeshResource.generateText(
            card.text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.03),
            containerFrame: CGRect(x: 0, y: 0, width: CGFloat(width * 0.8), height: CGFloat(height * 0.8)),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        var textMaterial = SimpleMaterial()
        textMaterial.color = .init(tint: uiColorFromHex(card.textColor))

        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

        // Center the text
        let bounds = textMesh.bounds
        textEntity.position = [
            -bounds.center.x,
            -bounds.center.y,
            0
        ]

        return textEntity
    }

    private func uiColorFromHex(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func navigateToPreviousCard() {
        withAnimation {
            currentCardIndex = max(0, currentCardIndex - 1)
        }
    }

    private func navigateToNextCard() {
        withAnimation {
            currentCardIndex = min(cards.count - 1, currentCardIndex + 1)
        }
    }
}

#Preview {
    ImmersiveCardSpaceView()
        .modelContainer(for: WordCard.self, inMemory: true)
}
#endif
