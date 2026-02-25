import SwiftUI
import SwiftData
import CloudKit

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registered for remote notifications")
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}
#else
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registered for remote notifications")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}
#endif

struct NewCardCommandKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var newCardAction: (() -> Void)? {
        get { self[NewCardCommandKey.self] }
        set { self[NewCardCommandKey.self] = newValue }
    }
}

@main
struct ValenceApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    #if os(macOS)
    @FocusedValue(\.newCardAction) var newCardAction
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([WordCard.self])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.mjbernaski.wordcard.app")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("✅ SwiftData container created with CloudKit sync")
            print("📁 Database URL: \(config.url)")
            SharedModelContainer.container = container
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Card") {
                    newCardAction?()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(newCardAction == nil)
            }
        }
        #endif
    }
}
