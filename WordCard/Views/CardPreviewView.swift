import SwiftUI

private struct CardTextSingleLineWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CardPreviewView: View {
    let text: String
    let backgroundColor: Color
    let textColor: Color
    let fontStyle: FontStyle
    let cornerRadius: CGFloat
    let borderColor: Color?
    let borderWidth: CGFloat
    var notes: String = ""

    @State private var singleLineWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let displayText = text.isEmpty ? "Preview" : text
            let font = fontForStyle(fontStyle, size: geometry.size, text: displayText)
            let availableWidth = geometry.size.width * 0.8
            let wraps = singleLineWidth > availableWidth * 1.8
            let textAlignment: TextAlignment = wraps ? .leading : .center
            let frameAlignment: Alignment = wraps ? .leading : .center

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)

                VStack(spacing: 0) {
                    Text(displayText)
                        .font(font)
                        .foregroundStyle(text.isEmpty ? textColor.opacity(0.4) : textColor)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .minimumScaleFactor(0.5)
                        .lineLimit(nil)
                        .background {
                            Text(displayText)
                                .font(font)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .hidden()
                                .background {
                                    GeometryReader { measureGeo in
                                        Color.clear.preference(
                                            key: CardTextSingleLineWidthKey.self,
                                            value: measureGeo.size.width
                                        )
                                    }
                                }
                        }
                        .onPreferenceChange(CardTextSingleLineWidthKey.self) { width in
                            singleLineWidth = width
                        }

                    if !notes.isEmpty {
                        Spacer()
                            .frame(height: geometry.size.height * 0.08)
                        Text(notes)
                            .font(.system(size: max(geometry.size.height * 0.06, 6)))
                            .foregroundStyle(textColor.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                    }
                }
                .padding(geometry.size.width * 0.1)

                if let border = borderColor {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(border.opacity(0.4), lineWidth: borderWidth)
                }
            }
        }
        .aspectRatio(2, contentMode: .fit)
    }

    private func fontForStyle(_ style: FontStyle, size: CGSize, text: String) -> Font {
        let base = min(size.height * 0.4, size.width * 0.15)
        let fontSize = max(base * lengthScale(for: text.count), 9)

        switch style {
        case .elegant:
            return .custom("Georgia", size: fontSize)
        case .book:
            return .custom("Times New Roman", size: fontSize)
        case .apple:
            return .system(size: fontSize, weight: .light)
        }
    }

    private func lengthScale(for charCount: Int) -> CGFloat {
        switch charCount {
        case ...10: return 1.0
        case 11...20: return 0.85
        case 21...35: return 0.7
        default: return 0.55
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        switch length {
        case 6:
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8:
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        default:
            return nil
        }
    }

    func toHex() -> String {
        #if os(macOS)
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        #else
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        #endif

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    CardPreviewView(
        text: "Hello World",
        backgroundColor: .white,
        textColor: .black,
        fontStyle: .elegant,
        cornerRadius: 20,
        borderColor: Color(hex: "#CC785C"),
        borderWidth: 1
    )
    .frame(width: 300, height: 150)
    .padding()
}
