import Foundation
import Vapor

actor FileWatcherService {
    private let watchPath: URL
    private let cardStore: CardStore
    private let sseService: SSEService
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var lastModified: Date?

    init(watchPath: URL, cardStore: CardStore, sseService: SSEService) {
        self.watchPath = watchPath
        self.cardStore = cardStore
        self.sseService = sseService
    }

    func start() async throws {
        // Ensure file exists (create empty if needed)
        if !FileManager.default.fileExists(atPath: watchPath.path) {
            let emptyBackup = BackupFile.create(cards: [])
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(emptyBackup)
            try data.write(to: watchPath)
        }

        // Get initial modification date
        lastModified = try? FileManager.default.attributesOfItem(atPath: watchPath.path)[.modificationDate] as? Date

        // Open file descriptor for watching
        fileDescriptor = open(watchPath.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            throw FileWatcherError.cannotOpenFile
        }

        // Create dispatch source for file system events
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task {
                await self.handleFileChange()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            Task {
                await self.cleanup()
            }
        }

        self.source = source
        source.resume()

        print("File watcher started for: \(watchPath.path)")
    }

    func stop() {
        source?.cancel()
    }

    private func handleFileChange() async {
        // Debounce: check if file was actually modified
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: watchPath.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return
        }

        // Skip if modification date hasn't changed (avoids duplicate events)
        if let last = lastModified, modDate.timeIntervalSince(last) < 0.5 {
            return
        }
        lastModified = modDate

        // Small delay to ensure file is fully written
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        do {
            let changedCards = try await cardStore.reloadFromFile()
            if !changedCards.isEmpty {
                print("Detected \(changedCards.count) card changes from external source")
                await sseService.broadcast(event: .cardsUpdated)
            }
        } catch {
            print("Error reloading cards after file change: \(error)")
        }
    }

    private func cleanup() {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    deinit {
        source?.cancel()
    }
}

enum FileWatcherError: Error {
    case cannotOpenFile
}
