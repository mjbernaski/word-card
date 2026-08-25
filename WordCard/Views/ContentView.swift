import SwiftUI
import SwiftData
#if !os(tvOS)
import CoreSpotlight
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditor = false
    @State private var selectedCard: WordCard?
    @StateObject private var syncMonitor = CloudKitSyncMonitor()
    #if os(macOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif
    #if os(visionOS)
    @State private var showingCardSpace = false
    #elseif os(tvOS)
    @State private var showingShowcase = false
    #endif

    var body: some View {
        #if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CardListView(selectedCard: $selectedCard, showingEditor: $showingEditor)
                .navigationSplitViewColumnWidth(min: 240, ideal: 320)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        SyncStatusDot(syncMonitor: syncMonitor)
                    }
                    ToolbarItem(placement: .principal) {
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
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingEditor) {
            CardEditorView()
        }
        .focusedSceneValue(\.newCardAction) {
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
        #elseif os(tvOS)
        NavigationStack {
            CardListView(selectedCard: $selectedCard, showingEditor: .constant(false))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        SyncStatusDot(syncMonitor: syncMonitor)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingShowcase = true
                        } label: {
                            Label("Showcase", systemImage: "sparkles.rectangle.stack")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        CardCountBadge()
                    }
                }
                .navigationDestination(for: WordCard.self) { card in
                    CardDetailView(card: card)
                }
                .onAppear {
                    syncMonitor.setModelContainer(modelContext.container)
                }
        }
        .fullScreenCover(isPresented: $showingShowcase) {
            CardShowcaseView()
                .modelContainer(modelContext.container)
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

#Preview {
    ContentView()
        .modelContainer(for: WordCard.self, inMemory: true)
}
