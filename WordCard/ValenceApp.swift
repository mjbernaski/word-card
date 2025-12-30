import SwiftUI
import SwiftData

@main
struct ValenceApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([WordCard.self])

        // Use local-only storage - sync is handled by iCloudDriveSyncService
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [localConfig])
            print("✅ Local storage container created")
            print("📁 Database URL: \(localConfig.url)")
            print("☁️ Sync will be handled via iCloud Drive file sync")
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Configure and start iCloud Drive sync on all platforms
                    iCloudDriveSyncService.shared.configure(modelContext: sharedModelContainer.mainContext)
                    iCloudDriveSyncService.shared.startSync()

                    #if os(macOS)
                    // Also configure LAN sync service (disabled by default)
                    SyncFileService.shared.configure(modelContext: sharedModelContainer.mainContext)
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Card") {
                    NotificationCenter.default.post(name: .newCard, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .appSettings) {
                Divider()
                Button("Sync Now") {
                    iCloudDriveSyncService.shared.forceSync()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()
                Toggle("LAN Sync", isOn: Binding(
                    get: { SyncFileService.shared.isEnabled },
                    set: { enabled in
                        if enabled {
                            SyncFileService.shared.startSync()
                        } else {
                            SyncFileService.shared.stopSync()
                        }
                    }
                ))
            }
        }
        #endif
    }
}

extension Notification.Name {
    static let newCard = Notification.Name("newCard")
}