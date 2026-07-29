import CloudKit
import Foundation
import SwiftData
import SwiftUI

enum SyncStatus {
    case syncing
    case synced
    case error
    case disabled
    case unknown
}

@MainActor
class CloudKitSyncMonitor: ObservableObject {
    @Published var syncStatus: SyncStatus = .unknown
    @Published var errorMessage: String?
    @Published var lastSyncTime: Date?

    private var accountStatusTimer: Timer?
    private var modelContainer: ModelContainer?
    private var syncIndicatorTask: Task<Void, Never>?
    private var syncCompletionTask: Task<Void, Never>?
    private let launchedAt = Date()
    private let automaticSyncGracePeriod: TimeInterval = 30

    init() {
        checkiCloudStatus()
        startMonitoring()
    }

    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
    }

    deinit {
        accountStatusTimer?.invalidate()
        syncIndicatorTask?.cancel()
        syncCompletionTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    private func startMonitoring() {
        accountStatusTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkiCloudStatus()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountChange),
            name: .CKAccountChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }

    @objc private func handleAccountChange() {
        Task { @MainActor in
            checkiCloudStatus()
        }
    }

    @objc private func handleDataChange() {
        Task { @MainActor in
            guard Date().timeIntervalSince(launchedAt) >= automaticSyncGracePeriod else {
                return
            }

            if syncStatus != .error && syncStatus != .disabled {
                syncIndicatorTask?.cancel()
                syncCompletionTask?.cancel()

                // Remote-change notifications often arrive in short bursts after
                // the data is already available. Defer the yellow indicator so it
                // does not flash as soon as the first notification arrives.
                if syncStatus != .syncing {
                    syncIndicatorTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 750_000_000)
                        guard !Task.isCancelled else { return }
                        self.syncStatus = .syncing
                    }
                }

                syncCompletionTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    self.syncIndicatorTask?.cancel()
                    self.syncStatus = .synced
                    self.lastSyncTime = Date()
                }
            }
        }
    }

    private func deduplicateAfterSync() {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WordCard>()
        guard let allCards = try? context.fetch(descriptor) else { return }

        var seen: [UUID: WordCard] = [:]
        var toDelete: [WordCard] = []
        let sorted = allCards.sorted { $0.updatedAt > $1.updatedAt }
        for card in sorted {
            if seen[card.id] != nil {
                toDelete.append(card)
            } else {
                seen[card.id] = card
            }
        }

        if !toDelete.isEmpty {
            for card in toDelete {
                context.delete(card)
            }
            try? context.save()
            print("🧹 Auto-deduplicated \(toDelete.count) sync duplicate(s)")
        }
    }

    private func checkiCloudStatus() {
        if FileManager.default.ubiquityIdentityToken != nil {
            if syncStatus == .disabled || syncStatus == .unknown {
                syncStatus = .synced
                lastSyncTime = Date()
            }
            errorMessage = nil
        } else {
            syncStatus = .disabled
            errorMessage = "No iCloud account signed in"
        }
    }

    func forceSyncRefresh() {
        syncIndicatorTask?.cancel()
        syncCompletionTask?.cancel()
        syncStatus = .syncing
        errorMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task { @MainActor in
                self.checkiCloudStatus()
            }
        }
    }

    func updateSyncStatus() {
        checkiCloudStatus()
    }
}
