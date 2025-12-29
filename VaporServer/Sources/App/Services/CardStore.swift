import Foundation
import Vapor

actor CardStore {
    private var cards: [UUID: CardDTO] = [:]
    private let syncFilePath: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(syncFilePath: URL) {
        self.syncFilePath = syncFilePath

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - CRUD Operations

    func getAllCards(includeArchived: Bool = false) -> [CardDTO] {
        let allCards = Array(cards.values)
        if includeArchived {
            return allCards.sorted { $0.createdAt > $1.createdAt }
        }
        return allCards
            .filter { !$0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func getCard(id: UUID) -> CardDTO? {
        cards[id]
    }

    func createCard(_ card: CardDTO) async throws -> CardDTO {
        cards[card.id] = card
        try await saveToFile()
        return card
    }

    func updateCard(id: UUID, text: String) async throws -> CardDTO? {
        guard var card = cards[id] else { return nil }
        card.text = text
        card.updatedAt = Date()
        cards[id] = card
        try await saveToFile()
        return card
    }

    func archiveCard(id: UUID) async throws -> CardDTO? {
        guard var card = cards[id] else { return nil }
        card.isArchived = true
        card.archivedAt = Date()
        card.updatedAt = Date()
        cards[id] = card
        try await saveToFile()
        return card
    }

    func deleteCard(id: UUID) async throws -> Bool {
        guard cards.removeValue(forKey: id) != nil else { return false }
        try await saveToFile()
        return true
    }

    // MARK: - File Sync

    func loadFromFile() async throws {
        guard FileManager.default.fileExists(atPath: syncFilePath.path) else {
            // No file yet - start empty
            return
        }

        do {
            let data = try Data(contentsOf: syncFilePath)
            let backup = try decoder.decode(BackupFile.self, from: data)
            cards = Dictionary(uniqueKeysWithValues: backup.cards.map { ($0.id, $0) })
            print("Loaded \(cards.count) cards from sync file")
        } catch {
            print("Error loading sync file: \(error)")
            // Don't throw - just start with empty store
        }
    }

    func saveToFile() async throws {
        let allCards = Array(cards.values).sorted { $0.createdAt < $1.createdAt }
        let backup = BackupFile.create(cards: allCards)
        let data = try encoder.encode(backup)
        try data.write(to: syncFilePath, options: .atomic)
        print("Saved \(allCards.count) cards to sync file")
    }

    // Reload from file (called by FileWatcher when external changes detected)
    func reloadFromFile() async throws -> [CardDTO] {
        let oldCards = cards
        try await loadFromFile()

        // Return changed cards for SSE notification
        var changedCards: [CardDTO] = []
        for (id, card) in cards {
            if oldCards[id] != card {
                changedCards.append(card)
            }
        }
        // Also include cards that were deleted
        for (id, card) in oldCards where cards[id] == nil {
            var deletedCard = card
            deletedCard.isArchived = true
            changedCards.append(deletedCard)
        }

        return changedCards
    }
}
