import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditor = false
    @State private var selectedCard: WordCard?
    @StateObject private var syncMonitor = CloudKitSyncMonitor()
    #if os(visionOS)
    @State private var showingCardSpace = false
    #endif

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            CardListView(selectedCard: $selectedCard, showingEditor: $showingEditor)
                .navigationSplitViewColumnWidth(min: 200, ideal: 280)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        SyncStatusDot(syncMonitor: syncMonitor)
                    }
                    ToolbarItem(placement: .automatic) {
                        CardCountBadge()
                    }
                }
        } detail: {
            if let card = selectedCard {
                CardDetailView(card: card)
            } else {
                Text("Select a card")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingEditor) {
            CardEditorView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newCard)) { _ in
            showingEditor = true
        }
        .onAppear {
            syncMonitor.setModelContainer(modelContext.container)
        }
        #elseif os(visionOS)
        NavigationSplitView {
            CardListView(selectedCard: $selectedCard, showingEditor: $showingEditor)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        SyncStatusDot(syncMonitor: syncMonitor)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCardSpace = true
                        } label: {
                            Label("3D Space", systemImage: "cube.transparent")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        CardCountBadge()
                    }
                }
        } detail: {
            if let card = selectedCard {
                CardDetailView(card: card)
            } else {
                Text("Select a card")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                CardEditorView()
            }
        }
        .fullScreenCover(isPresented: $showingCardSpace) {
            NavigationStack {
                ImmersiveCardSpaceView()
            }
            .modelContainer(modelContext.container)
        }
        .onAppear {
            syncMonitor.setModelContainer(modelContext.container)
        }
        #else
        NavigationStack {
            VStack(spacing: 0) {
                CardListView(selectedCard: $selectedCard, showingEditor: $showingEditor)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SyncStatusDot(syncMonitor: syncMonitor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CardCountBadge()
                }
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack {
                    CardEditorView()
                }
            }
            .onAppear {
                syncMonitor.setModelContainer(modelContext.container)
            }
        }
        #endif
    }
}

struct SyncStatusDot: View {
    @ObservedObject var syncMonitor: CloudKitSyncMonitor

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 10, height: 10)
            .overlay {
                if syncMonitor.syncStatus == .syncing {
                    Circle()
                        .stroke(dotColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .modifier(PulseAnimation())
                }
            }
            .onTapGesture {
                syncMonitor.forceSyncRefresh()
            }
            .help(statusTooltip)
            .accessibilityLabel(statusTooltip)
    }

    private var dotColor: Color {
        switch syncMonitor.syncStatus {
        case .synced:
            return .green
        case .syncing:
            return .yellow
        case .error, .disabled, .unknown:
            return .red
        }
    }

    private var statusTooltip: String {
        switch syncMonitor.syncStatus {
        case .synced:
            return "iCloud: Synced"
        case .syncing:
            return "iCloud: Syncing..."
        case .error:
            return "iCloud: Error - \(syncMonitor.errorMessage ?? "Unknown error")"
        case .disabled:
            return "iCloud: Disabled - \(syncMonitor.errorMessage ?? "Sign in to iCloud")"
        case .unknown:
            return "iCloud: Checking..."
        }
    }
}

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0 : 1)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

struct SyncStatusView: View {
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.caption)
            
            Spacer()
            
            if syncMonitor.syncStatus == .error || syncMonitor.syncStatus == .disabled {
                Button("Fix") {
                    syncMonitor.forceSyncRefresh()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
    }
    
    private var statusIcon: String {
        switch syncMonitor.syncStatus {
        case .syncing: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.triangle"
        case .disabled: return "icloud.slash"
        case .unknown: return "questionmark.circle"
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
    
    private var statusText: String {
        if let errorMessage = syncMonitor.errorMessage {
            return errorMessage
        }
        
        switch syncMonitor.syncStatus {
        case .syncing: return "Syncing cards..."
        case .synced: return "Cards synced"
        case .error: return "Sync error"
        case .disabled: return "iCloud sync disabled"
        case .unknown: return "Checking sync status..."
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WordCard.self, inMemory: true)
}
