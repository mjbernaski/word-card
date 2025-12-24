import Foundation
import SwiftData
import Combine

#if os(macOS)
/// Service that syncs WordCard data with a JSON file for LAN web access.
/// Uses both file watching and periodic polling for reliable sync.
@MainActor
class SyncFileService: ObservableObject {
    static let shared = SyncFileService()

    @Published var isEnabled: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private var modelContext: ModelContext?
    private var syncTimer: Timer?
    private var isImporting = false
    private var isExporting = false
    private var lastFileModDate: Date?
    private var lastExportDate: Date?

    let syncFileURL: URL = {
        // Use absolute path to bypass sandbox redirection
        let realHome = "/Users/\(NSUserName())"
        let documentsURL = URL(fileURLWithPath: "\(realHome)/Documents/WordCard")
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        return documentsURL.appendingPathComponent("sync.json")
    }()

    private init() {}

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startSync() {
        guard !isEnabled else { return }
        isEnabled = true
        print("📡 LAN sync started - file: \(syncFileURL.path)")

        // Initial sync
        Task {
            await performFullSync()
        }

        // Start periodic sync timer (every 3 seconds for reliability)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForExternalChanges()
            }
        }
    }

    func stopSync() {
        isEnabled = false
        syncTimer?.invalidate()
        syncTimer = nil
        print("📡 LAN sync stopped")
    }

    // MARK: - Full Sync

    private func performFullSync() async {
        // Import first to get web changes, then export to push native changes
        await importFromFile()
        await exportCards()
    }

    // MARK: - Check for External Changes

    private func checkForExternalChanges() async {
        guard isEnabled, !isImporting, !isExporting else { return }

        // Check if file was modified externally
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: syncFileURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return
        }

        // Skip if we just exported (within last 2 seconds)
        if let lastExport = lastExportDate, Date().timeIntervalSince(lastExport) < 2.0 {
            lastFileModDate = modDate
            return
        }

        // Check if file changed since last check
        if let lastMod = lastFileModDate, modDate <= lastMod {
            return
        }

        lastFileModDate = modDate
        print("📡 Detected external file change, importing...")
        await importFromFile()
    }

    // MARK: - Export

    func exportCards() async {
        guard isEnabled, let modelContext = modelContext else { return }
        guard !isImporting else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let descriptor = FetchDescriptor<WordCard>()
            let cards = try modelContext.fetch(descriptor)

            let data = try BackupService.shared.exportCards(cards)
            try data.write(to: syncFileURL, options: .atomic)

            lastExportDate = Date()
            lastSyncDate = Date()

            // Update our tracked mod date so we don't re-import our own export
            if let attrs = try? FileManager.default.attributesOfItem(atPath: syncFileURL.path),
               let modDate = attrs[.modificationDate] as? Date {
                lastFileModDate = modDate
            }

            syncError = nil
            print("📤 Exported \(cards.count) cards to sync file")
        } catch {
            syncError = "Export failed: \(error.localizedDescription)"
            print("❌ Export error: \(error)")
        }
    }

    // MARK: - Import

    func importFromFile() async {
        guard isEnabled, let modelContext = modelContext else { return }
        guard !isExporting else { return }

        isImporting = true
        defer { isImporting = false }

        do {
            guard FileManager.default.fileExists(atPath: syncFileURL.path) else {
                return
            }

            let data = try Data(contentsOf: syncFileURL)
            let backup = try BackupService.shared.parseBackupFile(data)

            // Get existing cards
            let descriptor = FetchDescriptor<WordCard>()
            let existingCards = try modelContext.fetch(descriptor)

            // Import with "update existing" mode
            let result = BackupService.shared.importCards(
                from: backup,
                into: modelContext,
                existingCards: existingCards,
                mode: .updateExisting
            )

            if result.imported > 0 || result.updated > 0 {
                try modelContext.save()
                lastSyncDate = Date()
                print("📥 Imported \(result.imported) new, updated \(result.updated) cards")

                // After importing, export to ensure file has all cards
                await exportCards()
            }

            syncError = nil
        } catch {
            syncError = "Import failed: \(error.localizedDescription)"
            print("❌ Import error: \(error)")
        }
    }
}

// Extension to trigger exports after card operations
extension SyncFileService {
    func cardDidChange() {
        guard isEnabled else { return }
        Task {
            // Small delay to batch rapid changes
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            await exportCards()
        }
    }
}
#else
// Stub for non-macOS platforms
@MainActor
class SyncFileService: ObservableObject {
    static let shared = SyncFileService()
    @Published var isEnabled: Bool = false

    func configure(modelContext: ModelContext) {}
    func startSync() {}
    func stopSync() {}
    func exportCards() async {}
    func cardDidChange() {}
}
#endif
