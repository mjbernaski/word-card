import Foundation
import CoreData
import os

/// Observable CloudKit sync state for ImageCard, and the log of record for it.
///
/// SwiftData reports no sync errors of its own, so a failed setup, import, or
/// export is indistinguishable from an idle store: the app receives nothing and
/// says nothing about why. ImageCard shipped exactly that way — an iPhone whose
/// every upload was rejected looked identical to one with nothing to send, and
/// the only place the truth appeared was the device log. This observes
/// `eventChangedNotification` once, logs every event, and publishes the current
/// state so the UI can show it too.
@MainActor
@Observable
final class ImageCardSyncStatus {
    static let shared = ImageCardSyncStatus()

    enum Activity: Equatable {
        case idle
        case settingUp
        case importing
        case exporting

        var label: String {
            switch self {
            case .idle: return "Synced"
            case .settingUp: return "Connecting…"
            case .importing: return "Downloading…"
            case .exporting: return "Uploading…"
            }
        }
    }

    private(set) var activity: Activity = .idle
    /// Last failure, kept until a later event of any kind succeeds.
    private(set) var lastError: String?
    private(set) var lastSuccess: Date?

    @ObservationIgnored private var inFlight = 0
    @ObservationIgnored private var observer: NSObjectProtocol?

    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "mjbernaski.imagecard.app",
        category: "CloudKit"
    )

    private init() {}

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            // Event isn't Sendable, so pull out plain values before hopping.
            let type = event.type
            let endDate = event.endDate
            let succeeded = event.succeeded
            let failure = event.error?.localizedDescription

            Task { @MainActor in
                Self.shared.apply(
                    type: type,
                    endDate: endDate,
                    succeeded: succeeded,
                    failure: failure
                )
            }
        }
    }

    private func apply(
        type: NSPersistentCloudKitContainer.EventType,
        endDate: Date?,
        succeeded: Bool,
        failure: String?
    ) {
        let phase: String
        let running: Activity
        switch type {
        case .setup: phase = "setup";  running = .settingUp
        case .import: phase = "import"; running = .importing
        case .export: phase = "export"; running = .exporting
        @unknown default: phase = "unknown"; running = .idle
        }

        guard let endDate else {
            inFlight += 1
            activity = running
            logger.info("CloudKit \(phase, privacy: .public) started")
            return
        }

        inFlight = max(0, inFlight - 1)
        if inFlight == 0 { activity = .idle }

        if let failure {
            lastError = failure
            logger.error("CloudKit \(phase, privacy: .public) FAILED: \(failure, privacy: .public)")
        } else {
            lastError = nil
            lastSuccess = endDate
            logger.info("CloudKit \(phase, privacy: .public) finished, succeeded=\(succeeded, privacy: .public)")
        }
    }
}
