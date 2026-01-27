import Foundation
import SwiftData

struct CardBackup: Codable {
    let id: UUID
    let text: String
    let backgroundColor: String
    let textColor: String
    let fontStyle: String
    let category: String
    let cornerRadius: Int
    let borderColor: String?
    let borderWidth: Int
    let dpi: Int
    let createdAt: Date
    let updatedAt: Date
    let isArchived: Bool
    let archivedAt: Date?
    let notes: String

    // Custom decoder to handle backups without notes field (backward compatibility)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
        textColor = try container.decode(String.self, forKey: .textColor)
        fontStyle = try container.decode(String.self, forKey: .fontStyle)
        category = try container.decode(String.self, forKey: .category)
        cornerRadius = try container.decode(Int.self, forKey: .cornerRadius)
        borderColor = try container.decodeIfPresent(String.self, forKey: .borderColor)
        borderWidth = try container.decode(Int.self, forKey: .borderWidth)
        dpi = try container.decode(Int.self, forKey: .dpi)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    init(
        id: UUID,
        text: String,
        backgroundColor: String,
        textColor: String,
        fontStyle: String,
        category: String,
        cornerRadius: Int,
        borderColor: String?,
        borderWidth: Int,
        dpi: Int,
        createdAt: Date,
        updatedAt: Date,
        isArchived: Bool,
        archivedAt: Date?,
        notes: String
    ) {
        self.id = id
        self.text = text
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.fontStyle = fontStyle
        self.category = category
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.dpi = dpi
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.notes = notes
    }
}

struct BackupFile: Codable {
    let version: Int
    let exportDate: Date
    let appName: String
    let cards: [CardBackup]
}

enum BackupError: LocalizedError {
    case exportFailed(String)
    case importFailed(String)
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .importFailed(let message):
            return "Import failed: \(message)"
        case .invalidFile:
            return "Invalid backup file format"
        }
    }
}

struct ImportResult {
    let imported: Int
    let skipped: Int
    let updated: Int
}

class BackupService {
    static let shared = BackupService()

    private init() {}

    // MARK: - Export

    func exportCards(_ cards: [WordCard]) throws -> Data {
        let backupCards = cards.map { card in
            CardBackup(
                id: card.id,
                text: card.text,
                backgroundColor: card.backgroundColor,
                textColor: card.textColor,
                fontStyle: card.fontStyle.rawValue,
                category: card.category.rawValue,
                cornerRadius: card.cornerRadius,
                borderColor: card.borderColor,
                borderWidth: card.borderWidth,
                dpi: card.dpi,
                createdAt: card.createdAt,
                updatedAt: card.updatedAt,
                isArchived: card.isArchived,
                archivedAt: card.archivedAt,
                notes: card.notes
            )
        }

        let backup = BackupFile(
            version: 1,
            exportDate: Date(),
            appName: "WordCard",
            cards: backupCards
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(backup)
    }

    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = formatter.string(from: Date())
        return "WordCard_Backup_\(dateString).json"
    }

    // MARK: - Import

    func parseBackupFile(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.invalidFile
        }
    }

    func importCards(
        from backup: BackupFile,
        into context: ModelContext,
        existingCards: [WordCard],
        mode: ImportMode
    ) -> ImportResult {
        var imported = 0
        var skipped = 0
        var updated = 0

        let existingIDs = Set(existingCards.map { $0.id })
        // Use reduce to handle duplicate IDs (keep the most recent)
        let existingCardsByID = existingCards.reduce(into: [UUID: WordCard]()) { dict, card in
            if let existing = dict[card.id] {
                // Keep the more recently updated one
                if card.updatedAt > existing.updatedAt {
                    dict[card.id] = card
                }
            } else {
                dict[card.id] = card
            }
        }

        for backupCard in backup.cards {
            if existingIDs.contains(backupCard.id) {
                // Card already exists
                switch mode {
                case .skipDuplicates:
                    skipped += 1
                case .updateExisting:
                    if let existingCard = existingCardsByID[backupCard.id] {
                        updateCard(existingCard, from: backupCard)
                        updated += 1
                    }
                case .importAsNew:
                    // Create with new ID
                    let newCard = createCard(from: backupCard, withNewID: true)
                    context.insert(newCard)
                    imported += 1
                }
            } else {
                // New card - import it
                let newCard = createCard(from: backupCard, withNewID: false)
                context.insert(newCard)
                imported += 1
            }
        }

        return ImportResult(imported: imported, skipped: skipped, updated: updated)
    }

    private func createCard(from backup: CardBackup, withNewID: Bool) -> WordCard {
        let card = WordCard(
            id: withNewID ? UUID() : backup.id,
            text: backup.text,
            backgroundColor: backup.backgroundColor,
            textColor: backup.textColor,
            fontStyle: FontStyle(rawValue: backup.fontStyle) ?? .elegant,
            category: CardCategory(rawValue: backup.category) ?? .idea,
            cornerRadius: backup.cornerRadius,
            borderColor: backup.borderColor,
            borderWidth: backup.borderWidth,
            dpi: backup.dpi,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
            isArchived: backup.isArchived,
            archivedAt: backup.archivedAt,
            notes: backup.notes
        )
        return card
    }

    private func updateCard(_ card: WordCard, from backup: CardBackup) {
        card.text = backup.text
        card.backgroundColor = backup.backgroundColor
        card.textColor = backup.textColor
        card.fontStyle = FontStyle(rawValue: backup.fontStyle) ?? .elegant
        card.cornerRadius = backup.cornerRadius
        card.borderColor = backup.borderColor
        card.borderWidth = backup.borderWidth
        card.dpi = backup.dpi
        card.isArchived = backup.isArchived
        card.archivedAt = backup.archivedAt
        card.notes = backup.notes
        card.updatedAt = Date()
    }
}

enum ImportMode: String, CaseIterable {
    case skipDuplicates = "Skip duplicates"
    case updateExisting = "Update existing"
    case importAsNew = "Import as new"

    var description: String {
        switch self {
        case .skipDuplicates:
            return "Skip cards that already exist"
        case .updateExisting:
            return "Update existing cards with backup data"
        case .importAsNew:
            return "Import duplicates as new cards"
        }
    }
}

// MARK: - Deduplication

struct DeduplicationResult {
    let totalCards: Int
    let duplicatesRemoved: Int
    let uniqueCards: Int
}

extension BackupService {
    /// Finds and removes duplicate cards, keeping the most recently updated version.
    /// Duplicates are identified by matching text content (case-insensitive, trimmed).
    func deduplicateCards(in context: ModelContext, cards: [WordCard]) -> DeduplicationResult {
        var seen: [String: WordCard] = [:]
        var duplicatesToRemove: [WordCard] = []

        // Sort by updatedAt descending so we keep the most recent version
        let sortedCards = cards.sorted { $0.updatedAt > $1.updatedAt }

        for card in sortedCards {
            let normalizedText = card.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Skip empty cards
            guard !normalizedText.isEmpty else {
                duplicatesToRemove.append(card)
                continue
            }

            if seen[normalizedText] != nil {
                // This is a duplicate - mark for removal
                duplicatesToRemove.append(card)
            } else {
                // First occurrence (most recent) - keep it
                seen[normalizedText] = card
            }
        }

        // Remove duplicates
        for card in duplicatesToRemove {
            context.delete(card)
        }

        return DeduplicationResult(
            totalCards: cards.count,
            duplicatesRemoved: duplicatesToRemove.count,
            uniqueCards: seen.count
        )
    }

    /// Finds duplicates by UUID (same card synced multiple times)
    func deduplicateByID(in context: ModelContext, cards: [WordCard]) -> DeduplicationResult {
        var seen: [UUID: WordCard] = [:]
        var duplicatesToRemove: [WordCard] = []

        // Sort by updatedAt descending so we keep the most recent version
        let sortedCards = cards.sorted { $0.updatedAt > $1.updatedAt }

        for card in sortedCards {
            if seen[card.id] != nil {
                // Duplicate UUID - mark for removal
                duplicatesToRemove.append(card)
            } else {
                seen[card.id] = card
            }
        }

        // Remove duplicates
        for card in duplicatesToRemove {
            context.delete(card)
        }

        return DeduplicationResult(
            totalCards: cards.count,
            duplicatesRemoved: duplicatesToRemove.count,
            uniqueCards: seen.count
        )
    }
}
