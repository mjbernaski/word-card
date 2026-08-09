import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ImageCardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var card: ImageCard
    @State private var showingEditor = false
    @State private var showingFullZoom = false
    @State private var copiedToClipboardToast = false
    @State private var pendingExport: ImageCardExport?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Interactive Card Display with native aspect ratio
                ZStack(alignment: .topTrailing) {
                    ImageCardPreviewView(card: card, showTitleOverlay: false, showValenceBadge: true)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
                        .onTapGesture {
                            showingFullZoom = true
                        }

                    Button {
                        showingFullZoom = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline.bold())
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                    }
                    .padding(12)
                    .help("Zoom Full View")
                }
                .padding(.horizontal)

                if !card.title.isEmpty {
                    Text(card.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if !card.notes.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Notes", systemImage: "note.text")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(card.notes)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal)
                }

                // Details & Metadata Box
                GroupBox("Image Card Details") {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Category", value: card.category.displayName)
                        DetailRow(label: "Dimensions", value: "\(Int(card.imageWidth)) × \(Int(card.imageHeight)) px")
                        DetailRow(label: "Aspect Ratio", value: String(format: "%.2f : 1", card.aspectRatio))
                        DetailRow(label: "Corner Radius", value: "\(card.cornerRadius)px")
                        DetailRow(label: "Border", value: card.borderColor != nil ? "Yes (\(card.borderWidth)px)" : "None")
                        DetailRow(label: "Valence Rating", value: card.valence > 0 ? "+\(card.valence)" : "\(card.valence)")

                        Divider()

                        DetailRow(label: "Created", value: card.createdAt.formatted(date: .abbreviated, time: .shortened))
                        DetailRow(label: "Modified", value: card.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)

                // Action Buttons
                #if !os(tvOS)
                HStack(spacing: 16) {
                    Button {
                        copyImageToClipboard()
                    } label: {
                        Label(copiedToClipboardToast ? "Copied!" : "Copy Image", systemImage: copiedToClipboardToast ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedToClipboardToast ? .green : .accentColor)

                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        exportImage()
                    } label: {
                        Label("Share / Save", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                #endif
            }
            .padding(.vertical)
        }
        .navigationTitle(card.title.isEmpty ? "Image Card" : card.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                ImageCardEditorView(card: card)
            }
        }
        #if os(macOS)
        .sheet(isPresented: $showingFullZoom) {
            FullZoomImageViewer(card: card, isPresented: $showingFullZoom)
                .frame(minWidth: 600, minHeight: 500)
        }
        #else
        .fullScreenCover(isPresented: $showingFullZoom) {
            FullZoomImageViewer(card: card, isPresented: $showingFullZoom)
        }
        #endif
        .sheet(item: $pendingExport) { export in
            if let data = card.imageData {
                ImageShareSheetView(imageData: data, title: card.title.isEmpty ? "image_card" : card.title)
            }
        }
    }

    private func copyImageToClipboard() {
        guard let data = card.imageData else { return }
        ClipboardImageService.copyToClipboard(imageData: data)
        withAnimation {
            copiedToClipboardToast = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation {
                    copiedToClipboardToast = false
                }
            }
        }
    }

    private func exportImage() {
        if card.imageData != nil {
            pendingExport = ImageCardExport(id: UUID())
        }
    }
}

private struct ImageCardExport: Identifiable {
    let id: UUID
}

struct FullZoomImageViewer: View {
    let card: ImageCard
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let data = card.imageData, let platformImg = PlatformImage(data: data) {
                #if os(macOS)
                Image(nsImage: platformImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in scale = lastScale * val }
                            .onEnded { _ in lastScale = scale }
                    )
                #else
                Image(uiImage: platformImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in scale = lastScale * val }
                            .onEnded { _ in lastScale = scale }
                    )
                #endif
            }

            VStack {
                HStack {
                    if !card.title.isEmpty {
                        Text(card.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                Spacer()
            }
        }
    }
}

struct ImageShareSheetView: View {
    let imageData: Data
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var tempURL: URL?

    var body: some View {
        Group {
            if let tempURL {
                #if os(macOS)
                MacShareView(fileURL: tempURL, filename: safeFilename, dismiss: dismiss)
                #elseif os(iOS)
                ActivityView(fileURL: tempURL)
                #else
                Text("Export ready")
                #endif
            } else {
                ProgressView("Preparing file...")
            }
        }
        .task {
            let sanitized = safeFilename
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitized).png")
            try? imageData.write(to: url)
            await MainActor.run {
                tempURL = url
            }
        }
    }

    private var safeFilename: String {
        let sanitized = title
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            .prefix(30)
        return sanitized.isEmpty ? "image_card" : String(sanitized)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

#if os(macOS)
private struct MacShareView: View {
    let fileURL: URL
    let filename: String
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .font(.system(size: 48))
            Text(filename)
                .font(.headline)
            ShareLink(item: fileURL) {
                Label("Share Image", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            Button("Done") {
                dismiss()
            }
        }
        .padding(32)
        .frame(minWidth: 320, minHeight: 240)
    }
}
#elseif os(iOS)
private struct ActivityView: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
