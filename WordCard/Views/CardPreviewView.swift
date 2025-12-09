import SwiftUI

struct CardPreviewView: View {
    let text: String
    let backgroundColor: Color
    let textColor: Color
    let fontStyle: FontStyle
    let cornerRadius: CGFloat
    let borderColor: Color?
    let borderWidth: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)

                Text(text.isEmpty ? "Preview" : text)
                    .font(fontForStyle(fontStyle, size: geometry.size))
                    .foregroundStyle(text.isEmpty ? textColor.opacity(0.4) : textColor)
                    .multilineTextAlignment(.center)
                    .padding(geometry.size.width * 0.1)
                    .minimumScaleFactor(0.1)
                    .lineLimit(nil)

                if let border = borderColor {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(border.opacity(0.4), lineWidth: borderWidth)
                }
            }
        }
        .aspectRatio(2, contentMode: .fit)
    }

    private func fontForStyle(_ style: FontStyle, size: CGSize) -> Font {
        // Start with a larger initial font size
        let idealFontSize = min(size.height * 0.4, size.width * 0.15)
        // But never go below 9pt
        let fontSize = max(idealFontSize, 9)
        
        switch style {
        case .elegant:
            return .custom("Georgia", size: fontSize)
        case .book:
            return .custom("Times New Roman", size: fontSize)
        case .apple:
            return .system(size: fontSize, weight: .light)
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
