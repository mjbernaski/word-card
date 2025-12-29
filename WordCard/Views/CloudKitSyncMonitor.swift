import Foundation
import CloudKit
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

    private let container: CKContainer
    private var accountStatusTimer: Timer?
    private var syncStatusTimer: Timer?

    static let containerIdentifier = "iCloud.mjbernaski.wordcard.app"

    init() {
        self.container = CKContainer(identifier: Self.containerIdentifier)
        startMonitoring()
    }
    
    deinit {
        // Clean up timers and observers directly in deinit
        // since we can't call MainActor-isolated methods here
        accountStatusTimer?.invalidate()
        syncStatusTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func startMonitoring() {
        // Initial check
        checkAccountStatus()
        
        // Set up periodic checks
        accountStatusTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkAccountStatus()
            }
        }
        
        // Monitor for CloudKit notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitNotification),
            name: .CKAccountChanged,
            object: nil
        )
        
        // Monitor for data changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    private func stopMonitoring() {
        // This method can be called to stop monitoring while the object is still alive
        // Note: This is MainActor-isolated and cannot be called from deinit
        accountStatusTimer?.invalidate()
        syncStatusTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleCloudKitNotification() {
        Task { @MainActor in
            checkAccountStatus()
        }
    }
    
    @objc private func handleDataChange() {
        Task { @MainActor in
            // When data changes, assume we're syncing
            if syncStatus != .error && syncStatus != .disabled {
                syncStatus = .syncing
                
                // After a delay, check the status again
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    Task { @MainActor in
                        self.checkSyncStatus()
                    }
                }
            }
        }
    }
    
    private func checkAccountStatus() {
        Task {
            do {
                let accountStatus = try await container.accountStatus()
                
                await MainActor.run {
                    switch accountStatus {
                    case .available:
                        if syncStatus == .disabled || syncStatus == .unknown {
                            syncStatus = .syncing
                            checkSyncStatus()
                        }
                        errorMessage = nil
                    case .noAccount:
                        syncStatus = .disabled
                        errorMessage = "No iCloud account signed in"
                    case .restricted:
                        syncStatus = .disabled
                        errorMessage = "iCloud account is restricted"
                    case .couldNotDetermine:
                        syncStatus = .error
                        errorMessage = "Could not determine iCloud status"
                    @unknown default:
                        syncStatus = .error
                        errorMessage = "Unknown iCloud status"
                    }
                }
            } catch {
                await MainActor.run {
                    syncStatus = .error
                    errorMessage = "CloudKit account check failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func checkSyncStatus() {
        // Simulate sync status checking
        // In a real implementation, you might check for pending operations,
        // recent sync timestamps, or other CloudKit-specific indicators
        
        Task {
            // Add a small delay to simulate sync checking
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                // If we don't have any errors, assume we're synced
                if syncStatus != .error && syncStatus != .disabled {
                    syncStatus = .synced
                    lastSyncTime = Date()
                    errorMessage = nil
                }
            }
        }
    }
    
    func forceSyncRefresh() {
        syncStatus = .syncing
        errorMessage = nil
        
        // Reset and recheck everything
        Task {
            await checkAccountStatus()
            
            // Add a delay before checking sync status
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                checkSyncStatus()
            }
        }
    }
    
    // Method to manually trigger sync status update
    func updateSyncStatus() {
        checkAccountStatus()
    }
}

// Extension to provide convenience methods for common CloudKit operations
extension CloudKitSyncMonitor {
    func checkiCloudAvailability() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
    
    func getiCloudStatusMessage() async -> String {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return "Signed in"
            case .noAccount:
                return "Not signed in"
            case .restricted:
                return "Restricted"
            case .couldNotDetermine:
                return "Unknown"
            @unknown default:
                return "Unknown"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    func getCloudKitRecordCount() async -> Int? {
        let database = container.privateCloudDatabase
        let query = CKQuery(recordType: "CD_WordCard", predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 1000)
            return results.count
        } catch {
            print("CloudKit query error: \(error)")
            return nil
        }
    }
}