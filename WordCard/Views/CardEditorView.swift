#if !os(tvOS)
import SwiftUI
import SwiftData

struct CardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingCard: WordCard?

    @State private var text: String = ""
    @State private var notes: String = ""
    @State private var category: CardCategory = .idea
    @State private var backgroundColor: Color = .white
    @State private var textColor: Color = .black
    @State private var fontStyle: FontStyle = .elegant
    @State private var cornerRadius: Double = 20
    @State private var hasBorder: Bool = true
    @State private var borderColor: Color = Color(hex: "#CC785C") ?? .brown
    @State private var borderWidth: Double = 1
    @State private var valence: Double = 0
    @State private var duplicateMatches: [DuplicateMatch] = []
    @FocusState private var isTextFieldFocused: Bool


    init(card: WordCard? = nil) {
        self.existingCard = card
        if let card = card {
            _text = State(initialValue: card.text)
            _notes = State(initialValue: card.notes)
            _category = State(initialValue: card.category)
            _backgroundColor = State(initialValue: Color(hex: card.backgroundColor) ?? .white)
            _textColor = State(initialValue: Color(hex: card.textColor) ?? .black)
            _fontStyle = State(initialValue: card.fontStyle)
            _cornerRadius = State(initialValue: Double(card.cornerRadius))
            _hasBorder = State(initialValue: card.borderColor != nil)
            _borderColor = State(initialValue: card.borderColor.flatMap { Color(hex: $0) } ?? .brown)
            _borderWidth = State(initialValue: Double(card.borderWidth))
            _valence = State(initialValue: Double(card.valence))
        }
    }

    var body: some View {
        Form {
            Section("Preview") {
                CardPreviewView(
                    text: text,
                    backgroundColor: backgroundColor,
                    textColor: textColor,
                    fontStyle: fontStyle,
                    cornerRadius: cornerRadius,
                    borderColor: hasBorder ? borderColor : nil,
                    borderWidth: borderWidth
                )
                .frame(height: 120)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Text") {
                TextField("Enter text", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($isTextFieldFocused)
                    .onChange(of: text) { _, newText in
                        checkForDuplicates(in: newText)
                    }
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }

            if existingCard == nil && !duplicateMatches.isEmpty {
                Section {
                    ForEach(duplicateMatches) { match in
                        HStack(alignment: .top, spacing: 12) {
                            CardPreviewView(
                                text: match.text,
                                backgroundColor: Color(hex: match.backgroundColor) ?? .white,
                                textColor: Color(hex: match.textColor) ?? .black,
                                fontStyle: match.fontStyle,
                                cornerRadius: CGFloat(match.cornerRadius),
                                borderColor: match.borderColor.flatMap { Color(hex: $0) },
                                borderWidth: CGFloat(match.borderWidth)
                            )
                            .frame(width: 90, height: 45)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.text)
                                    .font(.subheadline)
                                    .lineLimit(3)
                                Text(match.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 2)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                } header: {
                    Label("Similar Cards", systemImage: "square.on.square")
                } footer: {
                    Text("These existing cards share words with what you're typing.")
                }
            }


            Section {
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Add notes about this card...")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
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
                    ForEach(CardCategory.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.iconName).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: category) { _, newCategory in
                    backgroundColor = Color(hex: newCategory.defaultBackgroundColor) ?? .white
                }
            }

            Section("Valence") {
                #if os(macOS)
                Stepper(value: $valence, in: -5...5, step: 1) {
                    HStack {
                        Text("Valence")
                        Spacer()
                        Text("\(Int(valence))")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(valence > 0 ? .green : valence < 0 ? .red : .secondary)
                    }
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
                HStack {
                    Spacer()
                    Text("\(Int(valence))")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(valence > 0 ? .green : valence < 0 ? .red : .secondary)
                    Spacer()
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { drag in
                            let vertical = drag.translation.height
                            if vertical < -20 && valence < 5 {
                                valence += 1
                            } else if vertical > 20 && valence > -5 {
                                valence -= 1
                            }
                        }
                )
                #endif
            }

            Section("Colors") {
                ColorPicker("Background", selection: $backgroundColor)
                ColorPicker("Text", selection: $textColor)
            }

            Section("Style") {
                Picker("Font Style", selection: $fontStyle) {
                    ForEach(FontStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }

                HStack {
                    Text("Corner Radius")
                    Slider(value: $cornerRadius, in: 0...50, step: 1)
                    Text("\(Int(cornerRadius))")
                        .frame(width: 30)
                }
            }

            Section("Border") {
                Toggle("Show Border", isOn: $hasBorder)

                if hasBorder {
                    ColorPicker("Border Color", selection: $borderColor)

                    HStack {
                        Text("Border Width")
                        Slider(value: $borderWidth, in: 1...5, step: 1)
                        Text("\(Int(borderWidth))")
                            .frame(width: 20)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(existingCard == nil ? "New Card" : "Edit Card")
        .onAppear {
            if existingCard == nil {
                isTextFieldFocused = true
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func checkForDuplicates(in input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard existingCard == nil, trimmed.count >= 3 else {
            if !duplicateMatches.isEmpty { duplicateMatches = [] }
            return
        }

        let container = modelContext.container
        Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<WordCard>()
            guard let cards = try? context.fetch(descriptor) else { return }
            let active = cards.filter { !$0.isArchived }
            let matches = DuplicateDetector.matches(for: trimmed, in: active, limit: 5)
            await MainActor.run {
                self.duplicateMatches = matches
            }
        }
    }

    private func saveCard() {
        if let card = existingCard {
            card.text = text
            card.notes = notes
            card.category = category
            card.backgroundColor = backgroundColor.toHex()
            card.textColor = textColor.toHex()
            card.fontStyle = fontStyle
            card.cornerRadius = Int(cornerRadius)
            card.borderColor = hasBorder ? borderColor.toHex() : nil
            card.borderWidth = Int(borderWidth)
            card.valence = Int(valence)
            card.updatedAt = Date()
        } else {
            let card = WordCard(
                text: text,
                backgroundColor: backgroundColor.toHex(),
                textColor: textColor.toHex(),
                fontStyle: fontStyle,
                category: category,
                cornerRadius: Int(cornerRadius),
                borderColor: hasBorder ? borderColor.toHex() : nil,
                borderWidth: Int(borderWidth),
                notes: notes,
                valence: Int(valence)
            )
            modelContext.insert(card)
        }

    }
}

struct DuplicateMatch: Identifiable, Sendable {
    let id: UUID
    let text: String
    let backgroundColor: String
    let textColor: String
    let fontStyle: FontStyle
    let cornerRadius: Int
    let borderColor: String?
    let borderWidth: Int
    let updatedAt: Date
}

enum DuplicateDetector {
    private static let stopWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "can", "her",
        "was", "one", "our", "out", "day", "get", "has", "him", "his", "how",
        "man", "new", "now", "old", "see", "two", "way", "who", "boy", "did",
        "its", "let", "put", "say", "she", "too", "use", "your", "with",
        "this", "that", "from", "have", "they", "what", "when", "where",
        "would", "there", "their", "been", "were", "will", "about", "into",
        "than", "them", "some", "just", "like", "make", "much", "such",
        "very", "more", "over", "only", "also", "then", "even", "after"
    ]

    static func tokens(in text: String) -> Set<String> {
        let lowered = text.lowercased()
        let cleaned = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.letters.contains(scalar) ? Character(scalar) : " "
        }
        let words = String(cleaned).split(separator: " ").map(String.init)
        return Set(words.filter { $0.count >= 3 && !stopWords.contains($0) })
    }

    static func matches(for input: String, in cards: [WordCard], limit: Int) -> [DuplicateMatch] {
        let inputTokens = tokens(in: input)
        guard !inputTokens.isEmpty else { return [] }

        let scored: [(card: WordCard, score: Int)] = cards.compactMap { card in
            let cardTokens = tokens(in: card.text)
            let shared = inputTokens.intersection(cardTokens).count
            return shared > 0 ? (card, shared) : nil
        }

        return scored
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.card.updatedAt > $1.card.updatedAt
            }
            .prefix(limit)
            .map { match in
                DuplicateMatch(
                    id: match.card.id,
                    text: match.card.text,
                    backgroundColor: match.card.backgroundColor,
                    textColor: match.card.textColor,
                    fontStyle: match.card.fontStyle,
                    cornerRadius: match.card.cornerRadius,
                    borderColor: match.card.borderColor,
                    borderWidth: match.card.borderWidth,
                    updatedAt: match.card.updatedAt
                )
            }
    }
}


#Preview {
    NavigationStack {
        CardEditorView()
    }
    .modelContainer(for: WordCard.self, inMemory: true)
}
#endif
