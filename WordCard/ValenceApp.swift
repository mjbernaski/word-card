import SwiftUI
import SwiftData
import CloudKit

@main
struct ValenceApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([WordCard.self])

        // Configure CloudKit with explicit container ID
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.mjbernaski.wordcard.app")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            print("✅ CloudKit container created successfully with: iCloud.mjbernaski.wordcard.app")

            // Log additional info
            print("📁 Database URL: \(cloudConfig.url)")

            return container
        } catch {
            print("❌ CloudKit container failed: \(error)")
            print("❌ Full error: \(String(describing: error))")
            
            // Check if this is a CloudKit availability issue
            if error.localizedDescription.contains("CloudKit") {
                print("🔧 CloudKit may not be available. Check:")
                print("   - iCloud account is signed in")
                print("   - iCloud Drive is enabled") 
                print("   - App has CloudKit capabilities")
                print("   - Sufficient iCloud storage")
            }

            // Fall back to local-only storage
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )

            do {
                let localContainer = try ModelContainer(for: schema, configurations: [localConfig])
                print("⚠️ Using local storage only - cards will not sync between devices")
                return localContainer
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if os(macOS)
                    // Configure LAN sync service
                    SyncFileService.shared.configure(modelContext: sharedModelContainer.mainContext)
                    SyncFileService.shared.startSync()
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
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
        #endif
    }
}

extension Notification.Name {
    static let newCard = Notification.Name("newCard")
}