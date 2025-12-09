import Foundation
import SwiftData

enum FontStyle: String, Codable, CaseIterable {
    case elegant = "elegant"
    case book = "book"
    case apple = "apple"

    var displayName: String {
        switch self {
        case .elegant: return "Elegant"
        case .book: return "Book"
        case .apple: return "Apple"
        }
    }

    var fontName: String {
        switch self {
        case .elegant: return "Georgia"
        case .book: return "Times New Roman"
        case .apple: return "SF Pro Light"
        }
    }
}

@Model
final class WordCard {
    var id: UUID
    var text: String
    var backgroundColor: String
    var textColor: String
    private var fontStyleRaw: String
    var cornerRadius: Int
    var borderColor: String?
    var borderWidth: Int
    var dpi: Int
    var createdAt: Date
    var updatedAt: Date

    @Transient
    var fontStyle: FontStyle {
        get { FontStyle(rawValue: fontStyleRaw) ?? .elegant }
        set { fontStyleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        text: String = "",
        backgroundColor: String = "#FFFFFF",
        textColor: String = "#000000",
        fontStyle: FontStyle = .elegant,
        cornerRadius: Int = 20,
        borderColor: String? = "#CC785C",
        borderWidth: Int = 1,
        dpi: Int = 150,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.fontStyleRaw = fontStyle.rawValue
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.dpi = dpi
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
