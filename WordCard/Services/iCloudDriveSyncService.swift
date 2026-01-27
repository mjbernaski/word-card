import Foundation
import SwiftData
import Combine

/// Service that syncs WordCard data via iCloud Drive file sync.
/// Works identically on macOS and iOS by using the ubiquity container.
@MainActor
class iCloudDriveSyncService: ObservableObject {
    static let shared = iCloudDriveSyncService()

    // MARK: - Published State

    @Published var syncStatus: SyncStatus = .unknown
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var localCardCount: Int = 0
    @Published var iCloudAvailable: Bool = false

    enum SyncStatus: String {
        case unknown = "Unknown"
        case checking = "Checking..."
        case syncing = "Syncing"
        case synced = "Synced"
        case error = "Error"
        case disabled = "iCloud Unavailable"
    }

    // MARK: - Private Properties

    private var modelContext: ModelContext?
    private var syncTimer: Timer?
    private var metadataQuery: NSMetadataQuery?
    private var isImporting = false
    private var isExporting = false
    private var lastFileModDate: Date?
    private var lastExportDate: Date?

    private let containerIdentifier = "iCloud.mjbernaski.wordcard.app"
    private let syncFileName = "WordCardSync.json"

    // MARK: - Computed Properties

    /// URL to the iCloud Drive sync file
    var syncFileURL: URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            return nil
        }
        let documentsURL = containerURL.appendingPathComponent("Documents")
        return documentsURL.appendingPathComponent(syncFileName)
    }

    /// Local fallback URL when iCloud is unavailable
    private var localSyncFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(syncFileName)
    }

    private init() {}

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkiCloudAvailability()
    }

    func startSync() {
        print("☁️ iCloud Drive sync starting...")
        syncStatus = .checking

        // Check iCloud availability
        checkiCloudAvailability()

        guard iCloudAvailable else {
            syncStatus = .disabled
            syncError = "iCloud Drive is not available. Check that you're signed into iCloud."
            print("❌ iCloud Drive not available")
            return
        }

        // Ensure Documents directory exists in iCloud container
        ensureiCloudDirectoryExists()

        // Start monitoring for changes from other devices
        startMetadataQuery()

        // Initial sync
        Task {
            await performFullSync()
        }

        // Periodic sync check (every 5 seconds)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForChanges()
            }
        }

        print("☁️ iCloud Drive sync started - file: \(syncFileURL?.path ?? "unavailable")")
    }

    func stopSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        stopMetadataQuery()
        syncStatus = .unknown
        print("☁️ iCloud Drive sync stopped")
    }

    // MARK: - iCloud Availability

    private func checkiCloudAvailability() {
        // Check if iCloud is available by trying to get the container URL
        if let _ = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            iCloudAvailable = true
            print("✅ iCloud container available: \(containerIdentifier)")
        } else {
            iCloudAvailable = false
            print("⚠️ iCloud container not available")
        }
    }

    private func ensureiCloudDirectoryExists() {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            return
        }

        let documentsURL = containerURL.appendingPathComponent("Documents")

        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            do {
                try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
                print("📁 Created iCloud Documents directory")
            } catch {
                print("❌ Failed to create iCloud Documents directory: \(error)")
            }
        }
    }

    // MARK: - Metadata Query (monitors iCloud changes)

    private func startMetadataQuery() {
        guard metadataQuery == nil else { return }

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, syncFileName)
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        query.start()
        metadataQuery = query
        print("🔍 Started iCloud metadata query")
    }

    private func stopMetadataQuery() {
        metadataQuery?.stop()
        metadataQuery = nil
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: nil)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: nil)
    }

    @objc private func metadataQueryDidUpdate(_ notification: Notification) {
        Task { @MainActor in
            print("☁️ iCloud file changed, syncing...")
            await importFromiCloud()
        }
    }

    @objc private func metadataQueryDidFinishGathering(_ notification: Notification) {
        Task { @MainActor in
            await performFullSync()
        }
    }

    // MARK: - Full Sync

    func performFullSync() async {
        guard iCloudAvailable else {
            syncStatus = .disabled
            return
        }

        syncStatus = .syncing

        // Import first to get changes from other devices
        await importFromiCloud()

        // Then export to push our changes
        await exportToiCloud()

        syncStatus = .synced
        lastSyncDate = Date()
    }

    // MARK: - Check for Changes

    private func checkForChanges() async {
        guard iCloudAvailable, !isImporting, !isExporting else { return }

        guard let fileURL = syncFileURL else { return }

        // Use file coordinator for safe access
        var coordinatorError: NSError?
        var shouldImport = false

        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &coordinatorError) { url in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let modDate = attrs[.modificationDate] as? Date else {
                return
            }

            // Skip if we just exported
            if let lastExport = lastExportDate, Date().timeIntervalSince(lastExport) < 3.0 {
                lastFileModDate = modDate
                return
            }

            // Check if file changed
            if let lastMod = lastFileModDate, modDate > lastMod {
                shouldImport = true
            }

            lastFileModDate = modDate
        }

        if shouldImport {
            print("☁️ Detected iCloud file change")
            await importFromiCloud()
        }
    }

    // MARK: - Export

    func exportToiCloud() async {
        guard iCloudAvailable, let modelContext = modelContext else { return }
        guard !isImporting else { return }
        guard let fileURL = syncFileURL else {
            print("❌ Cannot export: iCloud URL unavailable")
            return
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let descriptor = FetchDescriptor<WordCard>()
            let cards = try modelContext.fetch(descriptor)
            localCardCount = cards.count

            let data = try BackupService.shared.exportCards(cards)

            // Use file coordinator for safe writing
            var coordinatorError: NSError?
            var writeError: Error?

            NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { url in
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    writeError = error
                }
            }

            if let error = coordinatorError ?? writeError {
                throw error
            }

            lastExportDate = Date()
            lastSyncDate = Date()

            // Update tracked mod date
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let modDate = attrs[.modificationDate] as? Date {
                lastFileModDate = modDate
            }

            syncError = nil
            syncStatus = .synced
            print("📤 Exported \(cards.count) cards to iCloud Drive")
        } catch {
            syncError = "Export failed: \(error.localizedDescription)"
            syncStatus = .error
            print("❌ iCloud export error: \(error)")
        }
    }

    // MARK: - Import

    func importFromiCloud() async {
        guard iCloudAvailable, let modelContext = modelContext else { return }
        guard !isExporting else { return }
        guard let fileURL = syncFileURL else {
            print("❌ Cannot import: iCloud URL unavailable")
            return
        }

        isImporting = true
        defer { isImporting = false }

        do {
            // Check if file exists
            var fileExists = false
            var coordinatorError: NSError?

            NSFileCoordinator().coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &coordinatorError) { url in
                fileExists = FileManager.default.fileExists(atPath: url.path)
            }

            guard fileExists else {
                print("☁️ No sync file exists yet, will create on export")
                return
            }

            // Read file with coordination
            var fileData: Data?
            var readError: Error?

            NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { url in
                do {
                    fileData = try Data(contentsOf: url)
                } catch {
                    readError = error
                }
            }

            if let error = coordinatorError ?? readError {
                throw error
            }

            guard let data = fileData else {
                return
            }

            let backup = try BackupService.shared.parseBackupFile(data)

            // Get existing cards
            let descriptor = FetchDescriptor<WordCard>()
            let existingCards = try modelContext.fetch(descriptor)

            // Import with merge strategy
            let result = importCardsWithMerge(
                from: backup,
                into: modelContext,
                existingCards: existingCards
            )

            if result.imported > 0 || result.updated > 0 || result.deleted > 0 {
                try modelContext.save()
                lastSyncDate = Date()
                print("📥 Sync: +\(result.imported) new, ~\(result.updated) updated, -\(result.deleted) deleted")

                // Re-export to ensure consistency
                await exportToiCloud()
            }

            localCardCount = try modelContext.fetch(descriptor).count
            syncError = nil
            syncStatus = .synced
        } catch {
            syncError = "Import failed: \(error.localizedDescription)"
            syncStatus = .error
            print("❌ iCloud import error: \(error)")
        }
    }

    // MARK: - Merge Strategy

    struct MergeResult {
        let imported: Int
        let updated: Int
        let deleted: Int
    }

    private func importCardsWithMerge(
        from backup: BackupFile,
        into context: ModelContext,
        existingCards: [WordCard]
    ) -> MergeResult {
        var imported = 0
        var updated = 0
        var deleted = 0

        // Build lookup by ID
        let existingByID = Dictionary(existingCards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let backupByID = Dictionary(backup.cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Process backup cards
        for backupCard in backup.cards {
            if let existing = existingByID[backupCard.id] {
                // Card exists - update if backup is newer
                if backupCard.updatedAt > existing.updatedAt {
                    updateCard(existing, from: backupCard)
                    updated += 1
                }
            } else {
                // New card from another device
                let newCard = createCard(from: backupCard)
                context.insert(newCard)
                imported += 1
            }
        }

        // Check for cards deleted on other devices
        // A card is considered deleted if it exists locally but not in backup,
        // AND the backup has been updated more recently than the local card
        for existing in existingCards {
            if backupByID[existing.id] == nil {
                // Card not in backup - check if it was deleted elsewhere
                // Only delete if backup export date is after our card's update date
                if backup.exportDate > existing.updatedAt {
                    context.delete(existing)
                    deleted += 1
                }
            }
        }

        return MergeResult(imported: imported, updated: updated, deleted: deleted)
    }

    private func createCard(from backup: CardBackup) -> WordCard {
        WordCard(
            id: backup.id,
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
    }

    private func updateCard(_ card: WordCard, from backup: CardBackup) {
        card.text = backup.text
        card.backgroundColor = backup.backgroundColor
        card.textColor = backup.textColor
        card.fontStyle = FontStyle(rawValue: backup.fontStyle) ?? .elegant
        card.category = CardCategory(rawValue: backup.category) ?? .idea
        card.cornerRadius = backup.cornerRadius
        card.borderColor = backup.borderColor
        card.borderWidth = backup.borderWidth
        card.dpi = backup.dpi
        card.isArchived = backup.isArchived
        card.archivedAt = backup.archivedAt
        card.notes = backup.notes
        // Keep the backup's updatedAt to prevent sync loops
        card.updatedAt = backup.updatedAt
    }

    // MARK: - Manual Trigger

    func cardDidChange() {
        Task {
            // Small delay to batch rapid changes
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            await exportToiCloud()
        }
    }

    func forceSync() {
        Task {
            await performFullSync()
        }
    }
}
