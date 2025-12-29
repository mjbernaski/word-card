import Foundation
import Vapor

// MARK: - Card Data Transfer Object

struct CardDTO: Content, Equatable {
    let id: UUID
    var text: String
    var backgroundColor: String
    var textColor: String
    var fontStyle: String
    var category: String
    var cornerRadius: Int
    var borderColor: String?
    var borderWidth: Int
    var dpi: Int
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var archivedAt: Date?

    // Create a new card with defaults
    static func create(text: String, category: String = "idea") -> CardDTO {
        let now = Date()
        let backgroundColor: String
        switch category {
        case "readings":
            backgroundColor = "#F5DEB3" // wheat
        case "miscellaneous":
            backgroundColor = "#B0C4DE" // light steel blue
        default:
            backgroundColor = "#FFFFFF" // white for idea
        }

        return CardDTO(
            id: UUID(),
            text: text,
            backgroundColor: backgroundColor,
            textColor: "#000000",
            fontStyle: "elegant",
            category: category,
            cornerRadius: 20,
            borderColor: "#CC785C",
            borderWidth: 1,
            dpi: 150,
            createdAt: now,
            updatedAt: now,
            isArchived: false,
            archivedAt: nil
        )
    }

    // Archive this card
    func archived() -> CardDTO {
        var copy = self
        copy.isArchived = true
        copy.archivedAt = Date()
        copy.updatedAt = Date()
        return copy
    }
}

// MARK: - Backup File Format (matches native app)

struct BackupFile: Codable {
    let version: Int
    let exportDate: Date
    let appName: String
    var cards: [CardDTO]

    static func create(cards: [CardDTO]) -> BackupFile {
        BackupFile(
            version: 1,
            exportDate: Date(),
            appName: "WordCard",
            cards: cards
        )
    }
}

// MARK: - Create Card Request

struct CreateCardRequest: Content {
    let text: String
    let category: String?
}

// MARK: - Card Category Enum

enum CardCategory: String, CaseIterable {
    case idea
    case readings
    case miscellaneous

    var displayName: String {
        switch self {
        case .idea: return "Idea"
        case .readings: return "Readings"
        case .miscellaneous: return "Miscellaneous"
        }
    }

    var backgroundColor: String {
        switch self {
        case .idea: return "#FFFFFF"
        case .readings: return "#F5DEB3"
        case .miscellaneous: return "#B0C4DE"
        }
    }
}
