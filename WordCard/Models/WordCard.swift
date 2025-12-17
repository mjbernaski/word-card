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

enum ExportResolution: String, CaseIterable {
    case medium = "medium"
    case high = "high"
    case superHigh = "superHigh"

    var displayName: String {
        switch self {
        case .medium: return "Medium"
        case .high: return "High"
        case .superHigh: return "Super High"
        }
    }

    var dpi: Int {
        switch self {
        case .medium: return 150      // 450 x 225 px
        case .high: return 300        // 900 x 450 px
        case .superHigh: return 600   // 1800 x 900 px
        }
    }

    var dimensions: String {
        let width = 3 * dpi
        let height = Int(1.5 * Double(dpi))
        return "\(width) × \(height) px"
    }
}

enum CardCategory: String, Codable, CaseIterable {
    case idea = "idea"
    case readings = "readings"
    case miscellaneous = "miscellaneous"

    var displayName: String {
        switch self {
        case .idea: return "Idea"
        case .readings: return "Readings"
        case .miscellaneous: return "Miscellaneous"
        }
    }

    var defaultBackgroundColor: String {
        switch self {
        case .idea: return "#FFFFFF"           // White
        case .readings: return "#F5DEB3"       // Manilla/Wheat
        case .miscellaneous: return "#B0C4DE"  // Light steel blue
        }
    }

    var iconName: String {
        switch self {
        case .idea: return "lightbulb"
        case .readings: return "book"
        case .miscellaneous: return "square.grid.2x2"
        }
    }
}

@Model
final class WordCard {
    var id: UUID = UUID()
    var text: String = ""
    var backgroundColor: String = "#FFFFFF"
    var textColor: String = "#000000"
    private var fontStyleRaw: String = "elegant"
    private var categoryRaw: String = "idea"
    var cornerRadius: Int = 20
    var borderColor: String? = "#CC785C"
    var borderWidth: Int = 1
    var dpi: Int = 150
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isArchived: Bool = false
    var archivedAt: Date? = nil

    @Transient
    var fontStyle: FontStyle {
        get { FontStyle(rawValue: fontStyleRaw) ?? .elegant }
        set { fontStyleRaw = newValue.rawValue }
    }

    @Transient
    var category: CardCategory {
        get { CardCategory(rawValue: categoryRaw) ?? .idea }
        set {
            categoryRaw = newValue.rawValue
            // Optionally update background color when category changes
            backgroundColor = newValue.defaultBackgroundColor
        }
    }

    init(
        id: UUID = UUID(),
        text: String = "",
        backgroundColor: String? = nil,
        textColor: String = "#000000",
        fontStyle: FontStyle = .elegant,
        category: CardCategory = .idea,
        cornerRadius: Int = 20,
        borderColor: String? = "#CC785C",
        borderWidth: Int = 1,
        dpi: Int = 150,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.backgroundColor = backgroundColor ?? category.defaultBackgroundColor
        self.textColor = textColor
        self.fontStyleRaw = fontStyle.rawValue
        self.categoryRaw = category.rawValue
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.dpi = dpi
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    func archive() {
        isArchived = true
        archivedAt = Date()
        updatedAt = Date()
    }

    func restore() {
        isArchived = false
        archivedAt = nil
        updatedAt = Date()
    }
}
