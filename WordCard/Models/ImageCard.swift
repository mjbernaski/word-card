import Foundation
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ImageCategory: String, Codable, CaseIterable {
    case inspiration = "inspiration"
    case design = "design"
    case screenshot = "screenshot"
    case photo = "photo"
    case meme = "meme"
    case miscellaneous = "miscellaneous"

    var displayName: String {
        switch self {
        case .inspiration: return "Inspiration"
        case .design: return "Design"
        case .screenshot: return "Screenshot"
        case .photo: return "Photo"
        case .meme: return "Meme"
        case .miscellaneous: return "Miscellaneous"
        }
    }

    var iconName: String {
        switch self {
        case .inspiration: return "sparkles"
        case .design: return "paintpalette"
        case .screenshot: return "macwindow"
        case .photo: return "camera"
        case .meme: return "face.smiling"
        case .miscellaneous: return "photo.on.rectangle"
        }
    }

    var defaultBackgroundColor: String {
        switch self {
        case .inspiration: return "#1E1E2E"       // Deep slate
        case .design: return "#282C34"            // Dark graphite
        case .screenshot: return "#1A202C"        // Midnight blue
        case .photo: return "#2D3748"             // Slate gray
        case .meme: return "#1F2937"              // Dark charcoal
        case .miscellaneous: return "#27272A"     // Dark neutral
        }
    }
}

@Model
final class ImageCard {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var imageData: Data? = nil
    var imageWidth: Double = 300.0
    var imageHeight: Double = 200.0
    var backgroundColor: String = "#1E1E2E"
    private var categoryRaw: String = "inspiration"
    var cornerRadius: Int = 16
    var borderColor: String? = "#3A3D52"
    var borderWidth: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isArchived: Bool = false
    var archivedAt: Date? = nil
    var valence: Int = 0

    @Transient
    var aspectRatio: Double {
        guard imageHeight > 0 else { return 1.5 }
        return max(0.2, min(5.0, imageWidth / imageHeight))
    }

    @Transient
    var category: ImageCategory {
        get { ImageCategory(rawValue: categoryRaw) ?? .inspiration }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        notes: String = "",
        imageData: Data? = nil,
        imageWidth: Double = 300.0,
        imageHeight: Double = 200.0,
        backgroundColor: String? = nil,
        category: ImageCategory = .inspiration,
        cornerRadius: Int = 16,
        borderColor: String? = "#3A3D52",
        borderWidth: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        valence: Int = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.imageData = imageData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.backgroundColor = backgroundColor ?? category.defaultBackgroundColor
        self.categoryRaw = category.rawValue
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.valence = max(-5, min(5, valence))
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
