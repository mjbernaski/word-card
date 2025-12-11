import SwiftUI
import SwiftData

struct CardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingCard: WordCard?

    @State private var text: String = ""
    @State private var category: CardCategory = .idea
    @State private var backgroundColor: Color = .white
    @State private var textColor: Color = .black
    @State private var fontStyle: FontStyle = .elegant
    @State private var cornerRadius: Double = 20
    @State private var hasBorder: Bool = true
    @State private var borderColor: Color = Color(hex: "#CC785C") ?? .brown
    @State private var borderWidth: Double = 1
    @State private var dpi: Int = 150

    init(card: WordCard? = nil) {
        self.existingCard = card
        if let card = card {
            _text = State(initialValue: card.text)
            _category = State(initialValue: card.category)
            _backgroundColor = State(initialValue: Color(hex: card.backgroundColor) ?? .white)
            _textColor = State(initialValue: Color(hex: card.textColor) ?? .black)
            _fontStyle = State(initialValue: card.fontStyle)
            _cornerRadius = State(initialValue: Double(card.cornerRadius))
            _hasBorder = State(initialValue: card.borderColor != nil)
            _borderColor = State(initialValue: card.borderColor.flatMap { Color(hex: $0) } ?? .brown)
            _borderWidth = State(initialValue: Double(card.borderWidth))
            _dpi = State(initialValue: card.dpi)
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

            Section("Export Settings") {
                Picker("DPI", selection: $dpi) {
                    Text("72 (Screen)").tag(72)
                    Text("150 (Default)").tag(150)
                    Text("300 (Print)").tag(300)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(existingCard == nil ? "New Card" : "Edit Card")
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

    private func saveCard() {
        if let card = existingCard {
            card.text = text
            card.category = category
            card.backgroundColor = backgroundColor.toHex()
            card.textColor = textColor.toHex()
            card.fontStyle = fontStyle
            card.cornerRadius = Int(cornerRadius)
            card.borderColor = hasBorder ? borderColor.toHex() : nil
            card.borderWidth = Int(borderWidth)
            card.dpi = dpi
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
                dpi: dpi
            )
            modelContext.insert(card)
        }
    }
}

#Preview {
    NavigationStack {
        CardEditorView()
    }
    .modelContainer(for: WordCard.self, inMemory: true)
}
