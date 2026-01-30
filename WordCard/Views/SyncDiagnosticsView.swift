import SwiftUI
import SwiftData

struct SyncDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [WordCard]
    @StateObject private var syncMonitor = CloudKitSyncMonitor()

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
                        Label("iCloud Account", systemImage: "icloud")
                        Spacer()
                        Text(accountStatusText)
                            .foregroundStyle(accountStatusColor)
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

                Section("Actions") {
                    Button {
                        syncMonitor.forceSyncRefresh()
                    } label: {
                        HStack {
                            Label("Refresh Status", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if syncMonitor.syncStatus == .syncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                }

                Section("Troubleshooting") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If cards aren't syncing:")
                            .font(.headline)

                        troubleshootingItem("1.", "Check iCloud is signed in on all devices")
                        troubleshootingItem("2.", "Ensure iCloud Drive is enabled")
                        troubleshootingItem("3.", "Check network connectivity")
                        troubleshootingItem("4.", "Allow time for CloudKit to propagate changes")
                        troubleshootingItem("5.", "Restart the app if sync seems stuck")
                    }
                    .padding(.vertical, 4)
                }

                Section("Technical Info") {
                    HStack {
                        Label("Sync Method", systemImage: "externaldrive.badge.icloud")
                        Spacer()
                        Text("CloudKit (Automatic)")
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
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .error: return "Error"
        case .disabled: return "Disabled"
        case .unknown: return "Checking..."
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

    private var accountStatusText: String {
        switch syncMonitor.syncStatus {
        case .disabled: return syncMonitor.errorMessage ?? "Unavailable"
        case .error: return "Error"
        default: return "Available"
        }
    }

    private var accountStatusColor: Color {
        switch syncMonitor.syncStatus {
        case .disabled: return .red
        case .error: return .red
        default: return .green
        }
    }
}

#Preview {
    SyncDiagnosticsView()
        .modelContainer(for: WordCard.self, inMemory: true)
}
