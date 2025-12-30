import SwiftUI
import SwiftData

struct SyncDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [WordCard]
    @StateObject private var syncService = iCloudDriveSyncService.shared
    @State private var isRefreshing = false
    @State private var lastRefresh: Date?
    @State private var syncFileInfo: String = "Checking..."

    var body: some View {
        NavigationStack {
            List {
                Section("Sync Status") {
                    HStack {
                        Label("Status", systemImage: statusIcon)
                        Spacer()
                        Text(syncService.syncStatus.rawValue)
                            .foregroundStyle(statusColor)
                    }

                    HStack {
                        Label("iCloud Drive", systemImage: "icloud")
                        Spacer()
                        Text(syncService.iCloudAvailable ? "Available" : "Unavailable")
                            .foregroundStyle(syncService.iCloudAvailable ? .green : .red)
                    }

                    if let lastSync = syncService.lastSyncDate {
                        HStack {
                            Label("Last Sync", systemImage: "clock")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = syncService.syncError {
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

                Section("iCloud Drive Sync File") {
                    HStack {
                        Label("Sync File", systemImage: "doc.badge.clock")
                        Spacer()
                        Text(syncFileInfo)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    if syncService.syncFileURL != nil {
                        HStack {
                            Label("Location", systemImage: "folder")
                            Spacer()
                            Text("iCloud Drive/WordCard")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                Section("Actions") {
                    Button {
                        forceSync()
                    } label: {
                        HStack {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
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
                        troubleshootingItem("4.", "Wait a minute for iCloud to sync the file")
                        troubleshootingItem("5.", "Use 'Sync Now' on all devices")
                    }
                    .padding(.vertical, 4)
                }

                Section("Technical Info") {
                    HStack {
                        Label("Sync Method", systemImage: "externaldrive.badge.icloud")
                        Spacer()
                        Text("iCloud Drive File")
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
        switch syncService.syncStatus {
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        case .disabled: return "icloud.slash"
        case .unknown, .checking: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch syncService.syncStatus {
        case .syncing, .checking: return .blue
        case .synced: return .green
        case .error: return .red
        case .disabled: return .orange
        case .unknown: return .gray
        }
    }

    private func refreshDiagnostics() {
        Task {
            // Get sync file info
            if let syncURL = syncService.syncFileURL {
                if FileManager.default.fileExists(atPath: syncURL.path) {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: syncURL.path),
                       let size = attrs[.size] as? Int64 {
                        let formatter = ByteCountFormatter()
                        formatter.countStyle = .file
                        syncFileInfo = "Exists (\(formatter.string(fromByteCount: size)))"
                    } else {
                        syncFileInfo = "Exists"
                    }
                } else {
                    syncFileInfo = "Not yet created"
                }
            } else {
                syncFileInfo = "iCloud unavailable"
            }
            lastRefresh = Date()
        }
    }

    private func forceSync() {
        isRefreshing = true

        Task {
            await syncService.performFullSync()
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
