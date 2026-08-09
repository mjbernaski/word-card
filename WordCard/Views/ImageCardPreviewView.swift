import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

struct ImageCardPreviewView: View {
    let card: ImageCard
    var showTitleOverlay: Bool = true
    var showValenceBadge: Bool = true

    @State private var loadedImage: PlatformImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background / Matte container
            RoundedRectangle(cornerRadius: CGFloat(card.cornerRadius))
                .fill(Color(hex: card.backgroundColor) ?? Color(hex: card.category.defaultBackgroundColor) ?? Color.black.opacity(0.8))

            // Image Content
            Group {
                if let loadedImage {
                    #if os(macOS)
                    Image(nsImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    #else
                    Image(uiImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    #endif
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: card.category.iconName)
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        if !card.title.isEmpty {
                            Text(card.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(card.aspectRatio, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: max(0, CGFloat(card.cornerRadius) - CGFloat(card.borderWidth))))
            .padding(CGFloat(card.borderWidth))

            // Border overlay
            if let borderHex = card.borderColor, card.borderWidth > 0 {
                RoundedRectangle(cornerRadius: CGFloat(card.cornerRadius))
                    .stroke(Color(hex: borderHex) ?? Color.white.opacity(0.2), lineWidth: CGFloat(card.borderWidth))
            }

            // Category & Valence Badge
            if showValenceBadge && card.valence != 0 {
                VStack {
                    HStack {
                        Spacer()
                        Text(card.valence > 0 ? "+\(card.valence)" : "\(card.valence)")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                card.valence > 0 ? Color.green.opacity(0.85) : Color.red.opacity(0.85),
                                in: Capsule()
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    Spacer()
                }
                .padding(8)
            }

            // Title Caption Overlay
            if showTitleOverlay && (!card.title.isEmpty || !card.notes.isEmpty) {
                VStack(alignment: .leading, spacing: 2) {
                    if !card.title.isEmpty {
                        Text(card.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    if !card.notes.isEmpty {
                        Text(card.notes)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.75), .black.opacity(0.0)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    in: RoundedRectangle(cornerRadius: CGFloat(card.cornerRadius))
                )
            }
        }
        .aspectRatio(card.aspectRatio, contentMode: .fit)
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: card.imageData) { _, _ in
            loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() {
        guard loadedImage == nil, let data = card.imageData else { return }
        #if os(macOS)
        loadedImage = NSImage(data: data)
        #else
        loadedImage = UIImage(data: data)
        #endif
    }
}
