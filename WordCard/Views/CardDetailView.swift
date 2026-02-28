import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var card: WordCard
    @State private var showingEditor = false
    @State private var showingExporter = false
    @State private var exportedImage: CGImage?
    @State private var showingShareSheet = false
    @State private var showingResolutionPicker = false
    @State private var selectedResolution: ExportResolution = .medium
    @State private var notesExpanded = true

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

                if !card.notes.isEmpty {
                    #if os(tvOS)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)
                        Text(card.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    #else
                    GroupBox {
                        DisclosureGroup(isExpanded: $notesExpanded) {
                            Text(card.notes)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        } label: {
                            Label("Notes", systemImage: "note.text")
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal)
                    #endif
                }

                #if os(tvOS)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Card Details")
                        .font(.headline)
                    DetailRow(label: "Font Style", value: card.fontStyle.displayName)
                    DetailRow(label: "Corner Radius", value: "\(card.cornerRadius)px")
                    DetailRow(label: "Border", value: card.borderColor != nil ? "Yes (\(card.borderWidth)px)" : "None")
                    DetailRow(label: "DPI", value: "\(card.dpi)")
                    DetailRow(label: "Export Size", value: "\(Int(3 * Double(card.dpi)))×\(Int(1.5 * Double(card.dpi)))px")

                    Divider()

                    DetailRow(label: "Created", value: card.createdAt.formatted(date: .abbreviated, time: .shortened))
                    DetailRow(label: "Modified", value: card.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                #else
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
                #endif

                #if !os(tvOS)
                HStack(spacing: 16) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingResolutionPicker = true
                    } label: {
                        Label("Export PNG", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                #endif
            }
            .padding(.vertical)
        }
        .navigationTitle("Card")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if !os(tvOS)
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
        .confirmationDialog("Export Resolution", isPresented: $showingResolutionPicker, titleVisibility: .visible) {
            ForEach(ExportResolution.allCases, id: \.self) { resolution in
                Button("\(resolution.displayName) (\(resolution.dimensions))") {
                    selectedResolution = resolution
                    exportCard()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose the resolution for your exported image")
        }
        #endif
    }

    private func exportCard() {
        let exporter = PNGExporter()
        if let image = exporter.export(card: card, resolution: selectedResolution) {
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
    @State private var tempFileURL: URL?
    @State private var exportError: String?

    var body: some View {
        Group {
            if let url = tempFileURL {
                #if os(visionOS)
                VisionOSShareView(fileURL: url, filename: safeFilename, dismiss: dismiss)
                #elseif os(tvOS)
                Text("Export is not available on Apple TV.")
                    .foregroundStyle(.secondary)
                #elseif os(iOS)
                ActivityView(fileURL: url)
                #else
                MacShareView(fileURL: url, filename: safeFilename, dismiss: dismiss)
                #endif
            } else if let error = exportError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text("Export Failed")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Dismiss") { dismiss() }
                        .buttonStyle(.bordered)
                }
                .padding()
            } else {
                ProgressView("Preparing export...")
                    .padding()
            }
        }
        .task {
            await prepareExport()
        }
    }

    private func prepareExport() async {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(safeFilename).png")

        let exporter = PNGExporter()
        do {
            try exporter.saveToPNG(image: image, url: fileURL)
            await MainActor.run {
                tempFileURL = fileURL
            }
        } catch {
            await MainActor.run {
                exportError = error.localizedDescription
            }
        }
    }

    private var safeFilename: String {
        let sanitized = card.text
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            .prefix(30)
        return sanitized.isEmpty ? "word_card" : String(sanitized)
    }
}

#if os(visionOS)
import UIKit

struct VisionOSShareView: View {
    let fileURL: URL
    let filename: String
    let dismiss: DismissAction
    @State private var showingSaveConfirmation = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let uiImage = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 400, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("\(filename).png")
                    .font(.headline)

                ShareLink(item: fileURL) {
                    Label("Share Image", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Button("Save to Files") {
                    saveToFiles()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Export Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Saved!", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Image saved to Documents folder")
        }
        .alert("Save Failed", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func saveToFiles() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = documentsURL.appendingPathComponent("\(filename).png")

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: destURL)
            showingSaveConfirmation = true
        } catch {
            saveErrorMessage = error.localizedDescription
            showingSaveError = true
        }
    }
}

#elseif os(iOS)
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(tvOS)
// No share/export views needed on tvOS
#else
import AppKit
import UniformTypeIdentifiers

struct MacShareView: View {
    let fileURL: URL
    let filename: String
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 20) {
            if let nsImage = NSImage(contentsOf: fileURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300)
            }

            Text("\(filename).png")
                .font(.headline)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                ShareLink(item: fileURL) {
                    Label("Share...", systemImage: "square.and.arrow.up")
                }

                Button("Save As...") {
                    showSavePanel()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
        .frame(minWidth: 400)
    }

    private func showSavePanel() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(filename).png"
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let destURL = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: fileURL, to: destURL)
                    NSWorkspace.shared.activateFileViewerSelecting([destURL])
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Save Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
            dismiss()
        }
    }
}
#endif

#if !os(tvOS)
struct RandomCardPreviewView: View {
    let cards: [WordCard]
    @State var card: WordCard
    @State var cgImage: CGImage?
    @State private var tempFileURL: URL?
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let cgImage {
                        #if os(macOS)
                        Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 400, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        #else
                        Image(uiImage: UIImage(cgImage: cgImage))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 400, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        #endif
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary)
                            .frame(maxWidth: 400, maxHeight: 200)
                            .overlay { ProgressView() }
                    }

                    Text(card.text)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if !card.notes.isEmpty {
                        Text(card.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    HStack(spacing: 16) {
                        Button {
                            reroll()
                        } label: {
                            Label("Re-roll", systemImage: "die.face.5")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(cards.count <= 1 || isLoading)

                        if let url = tempFileURL {
                            ShareLink(item: url) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Random Card")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if cgImage == nil {
                let currentCard = card
                let image = await Task.detached {
                    PNGExporter().export(card: currentCard, resolution: .medium)
                }.value
                cgImage = image
            }
            prepareFile()
        }
    }

    private func reroll() {
        guard let newCard = cards.filter({ $0.id != card.id }).randomElement() ?? cards.randomElement() else { return }
        isLoading = true
        tempFileURL = nil
        card = newCard
        cgImage = nil
        Task.detached {
            let exporter = PNGExporter()
            let newImage = exporter.export(card: newCard, resolution: .medium)
            await MainActor.run {
                cgImage = newImage
                prepareFile()
                isLoading = false
            }
        }
    }

    private func prepareFile() {
        guard let cgImage else { return }
        let sanitized = card.text
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            .prefix(30)
        let filename = sanitized.isEmpty ? "word_card" : String(sanitized)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).png")
        let exporter = PNGExporter()
        try? exporter.saveToPNG(image: cgImage, url: url)
        tempFileURL = url
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
