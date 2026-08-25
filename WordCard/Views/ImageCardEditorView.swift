import SwiftUI
import SwiftData
import PhotosUI

struct ImageCardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingCard: ImageCard?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var category: ImageCategory = .inspiration
    @State private var imageData: Data?
    @State private var imageWidth: Double = 300.0
    @State private var imageHeight: Double = 200.0
    @State private var backgroundColor: Color = Color(hex: "#1E1E2E") ?? .black
    @State private var cornerRadius: Double = 16
    @State private var hasBorder: Bool = true
    @State private var borderColor: Color = Color(hex: "#3A3D52") ?? .gray
    @State private var borderWidth: Double = 1
    @State private var valence: Double = 0

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var pasteFeedback: String?
    @FocusState private var isTitleFocused: Bool

    init(card: ImageCard? = nil) {
        self.existingCard = card
        if let card = card {
            _title = State(initialValue: card.title)
            _notes = State(initialValue: card.notes)
            _category = State(initialValue: card.category)
            _imageData = State(initialValue: card.imageData)
            _imageWidth = State(initialValue: card.imageWidth)
            _imageHeight = State(initialValue: card.imageHeight)
            _backgroundColor = State(initialValue: Color(hex: card.backgroundColor) ?? .black)
            _cornerRadius = State(initialValue: Double(card.cornerRadius))
            _hasBorder = State(initialValue: card.borderColor != nil)
            _borderColor = State(initialValue: card.borderColor.flatMap { Color(hex: $0) } ?? .gray)
            _borderWidth = State(initialValue: Double(card.borderWidth))
            _valence = State(initialValue: Double(card.valence))
        }
    }

    private var aspectRatio: Double {
        guard imageHeight > 0 else { return 1.5 }
        return imageWidth / imageHeight
    }

    var body: some View {
        Form {
            // Image Preview & Import Section
            Section("Image Card Preview") {
                VStack(spacing: 12) {
                    if let data = imageData, let _ = PlatformImage(data: data) {
                        ImageCardPreviewView(
                            card: tempCard,
                            showTitleOverlay: true,
                            showValenceBadge: true
                        )
                        .frame(maxHeight: 260)
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("No Image Selected")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Paste from clipboard, choose from Photos, or select a file")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Image Action Buttons
                    HStack(spacing: 12) {
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label("Paste Clipboard", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Photos", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        #if !os(tvOS)
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("File", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        #endif
                    }

                    if let feedback = pasteFeedback {
                        Text(feedback)
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }

                    if imageData != nil {
                        HStack {
                            Text("Dimensions: \(Int(imageWidth)) × \(Int(imageHeight)) px")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "Aspect Ratio: %.2f : 1", aspectRatio))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Card Title") {
                TextField("Title / Caption (Optional)", text: $title)
                    .focused($isTitleFocused)
                    #if !os(macOS)
                    .textInputAutocapitalization(.sentences)
                    #endif
            }

            Section {
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Add notes, description, or tags...")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $notes)
                        .frame(minHeight: 70)
                        .scrollContentBackground(.hidden)
                        .onChange(of: notes) { _, newValue in
                            if newValue.count > 500 {
                                notes = String(newValue.prefix(500))
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Notes")
                    Spacer()
                    Text("\(notes.count)/500")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Category") {
                Picker("Category", selection: $category) {
                    ForEach(ImageCategory.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.iconName).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: category) { _, newCategory in
                    backgroundColor = Color(hex: newCategory.defaultBackgroundColor) ?? .black
                }
            }

            Section("Valence / Rating") {
                HStack {
                    Text("Valence")
                    Spacer()
                    Text("\(Int(valence))")
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(valence > 0 ? .green : valence < 0 ? .red : .secondary)
                }
                #if os(macOS)
                Stepper(value: $valence, in: -5...5, step: 1) {
                    Text("Score (-5 to +5)")
                }
                #else
                HStack {
                    Text("-5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $valence, in: -5...5, step: 1)
                    Text("+5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
            }

            Section("Styling & Matting") {
                ColorPicker("Matte / Frame Color", selection: $backgroundColor)

                HStack {
                    Text("Corner Radius")
                    Slider(value: $cornerRadius, in: 0...40, step: 1)
                    Text("\(Int(cornerRadius))px")
                        .frame(width: 45)
                        .font(.caption.monospacedDigit())
                }
            }

            Section("Border") {
                Toggle("Show Border", isOn: $hasBorder)

                if hasBorder {
                    ColorPicker("Border Color", selection: $borderColor)

                    HStack {
                        Text("Border Width")
                        Slider(value: $borderWidth, in: 1...5, step: 1)
                        Text("\(Int(borderWidth))px")
                            .frame(width: 35)
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(existingCard == nil ? "New Image Card" : "Edit Image Card")
        .onAppear {
            if existingCard == nil {
                isTitleFocused = true
            }
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                handleFileImport(url: url)
            }
        }
        #endif
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                    if let info = ClipboardImageService.processImageData(data) {
                        await MainActor.run {
                            self.imageData = info.data
                            self.imageWidth = info.width
                            self.imageHeight = info.height
                            self.pasteFeedback = "✅ Loaded image from Photos (\(Int(info.width))×\(Int(info.height)) px)"
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveCard()
                    dismiss()
                }
                .disabled(imageData == nil)
            }
        }
    }

    private var tempCard: ImageCard {
        ImageCard(
            title: title,
            notes: notes,
            imageData: imageData,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            backgroundColor: backgroundColor.toHex(),
            category: category,
            cornerRadius: Int(cornerRadius),
            borderColor: hasBorder ? borderColor.toHex() : nil,
            borderWidth: Int(borderWidth),
            valence: Int(valence)
        )
    }

    private func pasteFromClipboard() {
        if let info = ClipboardImageService.fetchImageFromClipboard() {
            self.imageData = info.data
            self.imageWidth = info.width
            self.imageHeight = info.height
            withAnimation {
                pasteFeedback = "📋 Pasted image from clipboard (\(Int(info.width)) × \(Int(info.height)) px)"
            }
        } else {
            withAnimation {
                pasteFeedback = "⚠️ No image found in clipboard"
            }
        }
    }

    private func handleFileImport(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        if let data = try? Data(contentsOf: url),
           let info = ClipboardImageService.processImageData(data, filename: url.lastPathComponent) {
            self.imageData = info.data
            self.imageWidth = info.width
            self.imageHeight = info.height
            withAnimation {
                pasteFeedback = "📁 Loaded \(url.lastPathComponent) (\(Int(info.width)) × \(Int(info.height)) px)"
            }
        }
    }

    private func saveCard() {
        guard let imageData else { return }

        if let card = existingCard {
            card.title = title
            card.notes = notes
            card.imageData = imageData
            card.imageWidth = imageWidth
            card.imageHeight = imageHeight
            card.category = category
            card.backgroundColor = backgroundColor.toHex()
            card.cornerRadius = Int(cornerRadius)
            card.borderColor = hasBorder ? borderColor.toHex() : nil
            card.borderWidth = Int(borderWidth)
            card.valence = Int(valence)
            card.updatedAt = Date()
        } else {
            let card = ImageCard(
                title: title,
                notes: notes,
                imageData: imageData,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                backgroundColor: backgroundColor.toHex(),
                category: category,
                cornerRadius: Int(cornerRadius),
                borderColor: hasBorder ? borderColor.toHex() : nil,
                borderWidth: Int(borderWidth),
                valence: Int(valence)
            )
            modelContext.insert(card)
        }
    }
}
