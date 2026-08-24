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

@main
struct ImageCardApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(ImageCardAppDelegate.self) private var appDelegate
    #else
    @UIApplicationDelegateAdaptor(ImageCardAppDelegate.self) private var appDelegate
    #endif

    private let modelContainer: ModelContainer = {
        ImageCardSyncStatus.shared.start()
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
                .task {
                    ImageCardCloudKitBackfill.runIfNeeded(in: modelContainer.mainContext)
                    ImageCardCloudKitBackfill.logInventory(in: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
