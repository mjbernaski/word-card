import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var card: WordCard
    @State private var showingEditor = false
    @State private var showingExporter = false
    @State private var exportedImage: CGImage?
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CardPreviewView(
                    text: card.text,
                    backgroundColor: Color(hex: card.backgroundColor) ?? .white,
                    textColor: Color(hex: card.textColor) ?? .black,
                    fontStyle: card.fontStyle,
                    cornerRadius: CGFloat(card.cornerRadius),
                    borderColor: card.borderColor.flatMap { Color(hex: $0) },
                    borderWidth: CGFloat(card.borderWidth)
                )
                .frame(maxWidth: 450, maxHeight: 225)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding()

                GroupBox("Card Details") {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Font Style", value: card.fontStyle.displayName)
                        DetailRow(label: "Corner Radius", value: "\(card.cornerRadius)px")
                        DetailRow(label: "Border", value: card.borderColor != nil ? "Yes (\(card.borderWidth)px)" : "None")
                        DetailRow(label: "DPI", value: "\(card.dpi)")
                        DetailRow(label: "Export Size", value: "\(Int(3 * Double(card.dpi)))×\(Int(1.5 * Double(card.dpi)))px")

                        Divider()

                        DetailRow(label: "Created", value: card.createdAt.formatted(date: .abbreviated, time: .shortened))
                        DetailRow(label: "Modified", value: card.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        exportCard()
                    } label: {
                        Label("Export PNG", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Card")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                CardEditorView(card: card)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = exportedImage {
                ShareSheetView(image: image, card: card)
            }
        }
    }

    private func exportCard() {
        let exporter = PNGExporter()
        if let image = exporter.export(card: card) {
            exportedImage = image
            showingShareSheet = true
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

struct ShareSheetView: View {
    let image: CGImage
    let card: WordCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        ActivityView(image: image, filename: safeFilename)
        #else
        MacShareView(image: image, filename: safeFilename, dismiss: dismiss)
        #endif
    }

    private var safeFilename: String {
        let sanitized = card.text
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            .prefix(30)
        return sanitized.isEmpty ? "word_card" : String(sanitized)
    }
}

#if os(iOS)
struct ActivityView: UIViewControllerRepresentable {
    let image: CGImage
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let uiImage = UIImage(cgImage: image)
        let controller = UIActivityViewController(
            activityItems: [uiImage],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct MacShareView: View {
    let image: CGImage
    let filename: String
    let dismiss: DismissAction

    @State private var saveURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300)

            Text("\(filename).png")
                .font(.headline)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save to Downloads") {
                    saveToDownloads()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
        .frame(minWidth: 400)
    }

    private func saveToDownloads() {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsURL.appendingPathComponent("\(filename).png")

        try? pngData.write(to: fileURL)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        dismiss()
    }
}
#endif

#Preview {
    let card = WordCard(text: "Hello World")
    return NavigationStack {
        CardDetailView(card: card)
    }
    .modelContainer(for: WordCard.self, inMemory: true)
}
