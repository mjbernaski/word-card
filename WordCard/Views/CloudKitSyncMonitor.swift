import CloudKit
import CoreData
import Foundation
import SwiftData
import SwiftUI
import os

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
    private var eventObserver: NSObjectProtocol?
    private var inFlightEvents = 0
    /// Last CloudKit failure, held until a later event succeeds. Kept apart from
    /// `errorMessage` so the 30-second account poll cannot quietly clear it.
    private var cloudKitError: String?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "mjbernaski.wordcard.app",
        category: "CloudKit"
    )

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
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
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

        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            // Event isn't Sendable, so pull out plain values before hopping.
            let phase: String
            switch event.type {
            case .setup: phase = "setup"
            case .import: phase = "import"
            case .export: phase = "export"
            @unknown default: phase = "unknown"
            }
            let endDate = event.endDate
            let succeeded = event.succeeded
            let failure = event.error?.localizedDescription

            Task { @MainActor in
                self?.applyEvent(
                    phase: phase,
                    endDate: endDate,
                    succeeded: succeeded,
                    failure: failure
                )
            }
        }
    }

    /// Folds a CloudKit setup/import/export event into the published state.
    ///
    /// SwiftData reports no sync errors of its own, so without this a rejected
    /// export is indistinguishable from an idle store. That is how a missing
    /// `CD_isItalic` in the production schema killed both upload and download
    /// while the status dot stayed green: the only record of it was the device
    /// log. Every event is logged, and a failure now reaches the UI.
    private func applyEvent(
        phase: String,
        endDate: Date?,
        succeeded: Bool,
        failure: String?
    ) {
        guard let endDate else {
            inFlightEvents += 1
            syncIndicatorTask?.cancel()
            syncCompletionTask?.cancel()
            syncStatus = .syncing
            logger.info("CloudKit \(phase, privacy: .public) started")
            return
        }

        inFlightEvents = max(0, inFlightEvents - 1)

        if let failure {
            // A real failure outranks the remote-change heuristic, which would
            // otherwise flip the dot back to green two seconds later.
            syncIndicatorTask?.cancel()
            syncCompletionTask?.cancel()
            cloudKitError = failure
            errorMessage = failure
            syncStatus = .error
            logger.error("CloudKit \(phase, privacy: .public) FAILED: \(failure, privacy: .public)")
            return
        }

        cloudKitError = nil
        errorMessage = nil
        lastSyncTime = endDate
        if inFlightEvents == 0 {
            syncStatus = .synced
        }
        logger.info("CloudKit \(phase, privacy: .public) finished, succeeded=\(succeeded, privacy: .public)")
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
            // A CloudKit failure outranks this check: the account is signed in,
            // which is precisely why the export error must stay on screen.
            guard cloudKitError == nil else { return }
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
        cloudKitError = nil

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
