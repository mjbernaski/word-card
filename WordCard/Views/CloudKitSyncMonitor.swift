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

    init() {
        checkiCloudStatus()
        startMonitoring()
    }

    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
    }

    deinit {
        accountStatusTimer?.invalidate()
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
            if syncStatus != .error && syncStatus != .disabled {
                syncStatus = .syncing

                deduplicateAfterSync()

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    Task { @MainActor in
                        if self.syncStatus == .syncing {
                            self.syncStatus = .synced
                            self.lastSyncTime = Date()
                        }
                    }
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

extension Notification.Name {
    static let CKAccountChanged = Notification.Name("CKAccountChanged")
}
