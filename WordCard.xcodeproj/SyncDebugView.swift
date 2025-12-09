import SwiftUI
import SwiftData
import CloudKit

struct SyncDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncMonitor = CloudKitSyncMonitor()
    @Query private var allCards: [WordCard]
    
    var body: some View {
        NavigationView {
            Form {
                Section("CloudKit Status") {
                    HStack {
                        Text("Sync Status")
                        Spacer()
                        Label(syncStatusText, systemImage: syncStatusIcon)
                            .foregroundColor(syncStatusColor)
                    }
                    
                    if let errorMessage = syncMonitor.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if let lastSync = syncMonitor.lastSyncTime {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Data Statistics") {
                    HStack {
                        Text("Total Cards")
                        Spacer()
                        Text("\(allCards.count)")
                    }
                    
                    HStack {
                        Text("Recent Cards")
                        Spacer()
                        Text("\(recentCardsCount)")
                    }
                }
                
                Section("Troubleshooting") {
                    Button("Force Sync Refresh") {
                        syncMonitor.forceSyncRefresh()
                    }
                    
                    Button("Check CloudKit Account") {
                        checkCloudKitAccount()
                    }
                    
                    if syncMonitor.syncStatus == .error || syncMonitor.syncStatus == .disabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync Issues Detected")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("To fix sync issues:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Sign in to iCloud in Settings")
                                Text("• Enable iCloud Drive")
                                Text("• Check available iCloud storage")
                                Text("• Ensure all devices use same Apple ID")
                                Text("• Try turning iCloud Drive off/on")
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Card Creation Test") {
                    Button("Create Test Card") {
                        createTestCard()
                    }
                    
                    Text("Create a test card to verify sync is working")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Sync Debug")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
    
    private var syncStatusText: String {
        switch syncMonitor.syncStatus {
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .error: return "Error"
        case .disabled: return "Disabled"
        case .unknown: return "Unknown"
        }
    }
    
    private var syncStatusIcon: String {
        switch syncMonitor.syncStatus {
        case .syncing: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.triangle"
        case .disabled: return "icloud.slash"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var syncStatusColor: Color {
        switch syncMonitor.syncStatus {
        case .syncing: return .blue
        case .synced: return .green
        case .error: return .red
        case .disabled: return .orange
        case .unknown: return .gray
        }
    }
    
    private var recentCardsCount: Int {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return allCards.filter { $0.createdAt > oneDayAgo }.count
    }
    
    private func checkCloudKitAccount() {
        Task {
            do {
                let container = CKContainer.default()
                let accountStatus = try await container.accountStatus()
                
                await MainActor.run {
                    let message: String
                    switch accountStatus {
                    case .available:
                        message = "✅ CloudKit account is available"
                    case .noAccount:
                        message = "❌ No iCloud account signed in"
                    case .restricted:
                        message = "❌ iCloud account is restricted"
                    case .couldNotDetermine:
                        message = "❓ Could not determine iCloud status"
                    @unknown default:
                        message = "❓ Unknown iCloud status"
                    }
                    
                    print("CloudKit Account Status: \(message)")
                }
            } catch {
                print("❌ CloudKit Account Check Failed: \(error)")
            }
        }
    }
    
    private func createTestCard() {
        let testCard = WordCard(
            text: "Test Card - \(Date().formatted(date: .abbreviated, time: .shortened))",
            backgroundColor: "#E8F4F8",
            textColor: "#2C3E50",
            fontStyle: .book
        )
        
        modelContext.insert(testCard)
        
        do {
            try modelContext.save()
            print("✅ Test card created successfully")
        } catch {
            print("❌ Failed to create test card: \(error)")
        }
    }
}

#Preview {
    SyncDebugView()
        .modelContainer(for: WordCard.self, inMemory: true)
}