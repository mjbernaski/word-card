import Foundation
import SwiftData
import CloudKit

@MainActor
class CloudKitSyncMonitor: ObservableObject {
    @Published var syncStatus: SyncStatus = .unknown
    @Published var lastSyncTime: Date?
    @Published var errorMessage: String?
    
    enum SyncStatus {
        case unknown
        case syncing
        case synced
        case error
        case disabled
    }
    
    private var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Monitor CloudKit account status
        checkCloudKitAccountStatus()
        
        // Set up notifications for CloudKit changes
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkCloudKitAccountStatus()
        }
    }
    
    private func checkCloudKitAccountStatus() {
        let container = CKContainer.default()
        
        Task {
            do {
                let accountStatus = try await container.accountStatus()
                
                await MainActor.run {
                    switch accountStatus {
                    case .available:
                        self.syncStatus = .synced
                        self.errorMessage = nil
                    case .noAccount:
                        self.syncStatus = .disabled
                        self.errorMessage = "No iCloud account signed in"
                    case .restricted:
                        self.syncStatus = .error
                        self.errorMessage = "iCloud account restricted"
                    case .couldNotDetermine:
                        self.syncStatus = .unknown
                        self.errorMessage = "Could not determine iCloud status"
                    @unknown default:
                        self.syncStatus = .unknown
                        self.errorMessage = "Unknown iCloud status"
                    }
                }
            } catch {
                await MainActor.run {
                    self.syncStatus = .error
                    self.errorMessage = "CloudKit error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func forceSyncRefresh() {
        syncStatus = .syncing
        lastSyncTime = Date()
        
        // Trigger a refresh by updating a card's timestamp
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<WordCard>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            let cards = try modelContext.fetch(descriptor)
            if let firstCard = cards.first {
                firstCard.updatedAt = Date()
                try modelContext.save()
            }
        } catch {
            errorMessage = "Sync refresh failed: \(error.localizedDescription)"
            syncStatus = .error
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}