import SwiftUI
import SwiftData
import CloudKit

struct SyncDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [WordCard]
    @StateObject private var syncMonitor = CloudKitSyncMonitor()
    @State private var iCloudStatus: String = "Checking..."
    @State private var containerID: String = "Unknown"
    @State private var isRefreshing = false
    @State private var lastRefresh: Date?
    @State private var cloudKitRecordCount: Int?

    var body: some View {
        NavigationStack {
            List {
                Section("Sync Status") {
                    HStack {
                        Label("Status", systemImage: statusIcon)
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(statusColor)
                    }

                    HStack {
                        Label("iCloud Account", systemImage: "person.icloud")
                        Spacer()
                        Text(iCloudStatus)
                            .foregroundStyle(.secondary)
                    }

                    if let lastSync = syncMonitor.lastSyncTime {
                        HStack {
                            Label("Last Sync", systemImage: "clock")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = syncMonitor.errorMessage {
                        HStack {
                            Label("Error", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                            Spacer()
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }

                Section("Local Data") {
                    HStack {
                        Label("Total Cards", systemImage: "rectangle.stack")
                        Spacer()
                        Text("\(allCards.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Active Cards", systemImage: "rectangle.on.rectangle")
                        Spacer()
                        Text("\(allCards.filter { !$0.isArchived }.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Archived Cards", systemImage: "archivebox")
                        Spacer()
                        Text("\(allCards.filter { $0.isArchived }.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("CloudKit Data") {
                    HStack {
                        Label("Cloud Records", systemImage: "icloud")
                        Spacer()
                        if let count = cloudKitRecordCount {
                            Text("\(count)")
                                .foregroundStyle(count == allCards.count ? .green : .orange)
                        } else {
                            Text("Checking...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let count = cloudKitRecordCount, count != allCards.count {
                        HStack {
                            Label("Difference", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Spacer()
                            Text("\(abs(allCards.count - count)) cards")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Actions") {
                    Button {
                        forceSync()
                    } label: {
                        HStack {
                            Label("Force Sync Refresh", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isRefreshing)

                    Button {
                        refreshDiagnostics()
                    } label: {
                        Label("Refresh Diagnostics", systemImage: "arrow.clockwise")
                    }
                }

                Section("Troubleshooting") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If cards aren't syncing:")
                            .font(.headline)

                        troubleshootingItem("1.", "Check iCloud is signed in on all devices")
                        troubleshootingItem("2.", "Ensure iCloud Drive is enabled")
                        troubleshootingItem("3.", "Check network connectivity")
                        troubleshootingItem("4.", "Force close and reopen the app")
                        troubleshootingItem("5.", "Export backup from one device, import on others")
                    }
                    .padding(.vertical, 4)
                }

                Section("Technical Info") {
                    HStack {
                        Label("Container", systemImage: "externaldrive.badge.icloud")
                        Spacer()
                        Text(containerID)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        Label("App Version", systemImage: "info.circle")
                        Spacer()
                        Text(AppVersion.fullVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Sync Diagnostics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshDiagnostics()
            }
        }
    }

    private func troubleshootingItem(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private var statusIcon: String {
        switch syncMonitor.syncStatus {
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        case .disabled: return "icloud.slash"
        case .unknown: return "questionmark.circle"
        }
    }

    private var statusText: String {
        switch syncMonitor.syncStatus {
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .error: return "Error"
        case .disabled: return "Disabled"
        case .unknown: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch syncMonitor.syncStatus {
        case .syncing: return .blue
        case .synced: return .green
        case .error: return .red
        case .disabled: return .orange
        case .unknown: return .gray
        }
    }

    private func refreshDiagnostics() {
        Task {
            iCloudStatus = await syncMonitor.getiCloudStatusMessage()
            containerID = CloudKitSyncMonitor.containerIdentifier
            cloudKitRecordCount = await syncMonitor.getCloudKitRecordCount()
            lastRefresh = Date()
        }
    }

    private func forceSync() {
        isRefreshing = true
        syncMonitor.forceSyncRefresh()

        // Also trigger a model context save to push changes
        do {
            try modelContext.save()
        } catch {
            print("Error saving context during force sync: \(error)")
        }

        Task {
            // Wait for sync to propagate
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                isRefreshing = false
            }
            refreshDiagnostics()
        }
    }
}

#Preview {
    SyncDiagnosticsView()
        .modelContainer(for: WordCard.self, inMemory: true)
}
