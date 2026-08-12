import SwiftUI
import SwiftData
import CloudKit
import CoreData
import os

#if os(macOS)
private final class ImageCardAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
    }
}
#else
private final class ImageCardAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
}
#endif

/// Reports what CloudKit is actually doing with the ImageCard store.
///
/// SwiftData surfaces no sync errors of its own, so without this a failed
/// setup, import, or export is indistinguishable from an idle store — the
/// app simply never receives anything and says nothing about why.
enum ImageCardSyncLog {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "mjbernaski.imagecard.app",
        category: "CloudKit"
    )

    private static var observer: NSObjectProtocol?

    static func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            let phase = switch event.type {
            case .setup: "setup"
            case .import: "import"
            case .export: "export"
            @unknown default: "unknown"
            }

            if let error = event.error {
                logger.error("CloudKit \(phase, privacy: .public) FAILED: \(error.localizedDescription, privacy: .public)")
            } else if event.endDate == nil {
                logger.info("CloudKit \(phase, privacy: .public) started")
            } else {
                logger.info("CloudKit \(phase, privacy: .public) finished, succeeded=\(event.succeeded, privacy: .public)")
            }
        }
    }
}

@main
struct ImageCardApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(ImageCardAppDelegate.self) private var appDelegate
    #else
    @UIApplicationDelegateAdaptor(ImageCardAppDelegate.self) private var appDelegate
    #endif

    private let modelContainer: ModelContainer = {
        ImageCardSyncLog.start()
        let schema = Schema([ImageCard.self])
        let config = ModelConfiguration(
            "ImageCards",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.mjbernaski.imagecard.app")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("ImageCard SwiftData container created with CloudKit sync")
            return container
        } catch {
            fatalError("Could not create the ImageCard data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ImageCardContentView()
        }
        .modelContainer(modelContainer)
    }
}
