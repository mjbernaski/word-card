import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum CardSortOrder: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case recentlyUpdated = "Recently Updated"
    case alphabetical = "A-Z"
}

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: CardListView.activeCardsPredicate, sort: [
        SortDescriptor(\WordCard.createdAt, order: .reverse)
    ]) private var cards: [WordCard]

    private static let activeCardsPredicate = #Predicate<WordCard> { card in
        card.isArchived == false
    }
    @Query private var allCards: [WordCard]
    @AppStorage("cardSortOrder") private var sortOrder: CardSortOrder = .newestFirst

    private var sortedCards: [WordCard] {
        switch sortOrder {
        case .newestFirst:
            return cards.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return cards.sorted { $0.createdAt < $1.createdAt }
        case .recentlyUpdated:
            return cards.sorted { $0.updatedAt > $1.updatedAt }
        case .alphabetical:
            return cards.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
        }
    }
    @Binding var selectedCard: WordCard?
    @Binding var showingEditor: Bool
    @State private var searchText = ""
    @State private var showingArchive = false
    @State private var showingBackupOptions = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportData: Data?
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var showingImportModeSheet = false
    @State private var pendingImportURL: URL?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingDedupeConfirm = false
    @State private var dedupeResult: DeduplicationResult?
    @State private var showingDedupeResult = false
    @State private var showingSyncDiagnostics = false

    private var filteredCards: [WordCard] {
        let sorted = sortedCards
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                gridView
            } else {
                listView
            }
            #elseif os(visionOS)
            gridView
            #else
            gridView
            #endif
        }
        .navigationTitle("Cards")
        .searchable(text: $searchText, prompt: "Search cards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        showingArchive = true
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }

                    Divider()

                    Menu {
                        ForEach(CardSortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Sort By", systemImage: "arrow.up.arrow.down")
                    }

                    Divider()

                    Button {
                        exportBackup()
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }

                    Divider()

                    Button {
                        showingDedupeConfirm = true
                    } label: {
                        Label("Remove Duplicates", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        showingSyncDiagnostics = true
                    } label: {
                        Label("Sync Diagnostics", systemImage: "stethoscope")
                    }

                    Divider()

                    Text("WordCard \(AppVersion.displayString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingArchive) {
            ArchiveView()
        }
        .sheet(isPresented: $showingSyncDiagnostics) {
            SyncDiagnosticsView()
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: BackupDocument(data: exportData ?? Data()),
            contentType: .json,
            defaultFilename: BackupService.shared.generateFilename()
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .confirmationDialog("Import Options", isPresented: $showingImportModeSheet) {
            Button("Skip Duplicates") {
                performImport(mode: .skipDuplicates)
            }
            Button("Update Existing") {
                performImport(mode: .updateExisting)
            }
            Button("Import as New Cards") {
                performImport(mode: .importAsNew)
            }
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("How should duplicate cards be handled?")
        }
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = importResult {
                Text("Imported: \(result.imported)\nSkipped: \(result.skipped)\nUpdated: \(result.updated)")
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .confirmationDialog("Remove Duplicates", isPresented: $showingDedupeConfirm) {
            Button("By Content (same text)", role: .destructive) {
                performDedupe(byContent: true)
            }
            Button("By ID (sync duplicates)", role: .destructive) {
                performDedupe(byContent: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove duplicate cards, keeping the most recently updated version of each.")
        }
        .alert("Duplicates Removed", isPresented: $showingDedupeResult) {
            Button("OK", role: .cancel) {}
        } message: {
            if let result = dedupeResult {
                Text("Removed \(result.duplicatesRemoved) duplicate(s).\n\(result.uniqueCards) unique cards remaining.")
            }
        }
    }

    private func performDedupe(byContent: Bool) {
        if byContent {
            dedupeResult = BackupService.shared.deduplicateCards(in: modelContext, cards: allCards)
        } else {
            dedupeResult = BackupService.shared.deduplicateByID(in: modelContext, cards: allCards)
        }
        showingDedupeResult = true
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300))], spacing: 16) {
                ForEach(filteredCards) { card in
                    CardThumbnailView(card: card)
                        .onTapGesture {
                            selectedCard = card
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                archiveCard(card)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                }
            }
            .padding()
        }
        .overlay {
            if filteredCards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Tap + to create your first card")
                }
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredCards) { card in
                NavigationLink(value: card) {
                    HStack {
                        CardThumbnailView(card: card)
                            .frame(width: 120, height: 60)
                        Text(card.text)
                            .lineLimit(2)
                    }
                }
            }
            .onDelete(perform: archiveCards)
        }
        .navigationDestination(for: WordCard.self) { card in
            CardDetailView(card: card)
        }
        .overlay {
            if filteredCards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Tap + to create your first card")
                }
            }
        }
    }

    private func archiveCard(_ card: WordCard) {
        withAnimation {
            card.archive()
        }
    }

    private func archiveCards(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                filteredCards[index].archive()
            }
        }
    }

    private func exportBackup() {
        do {
            exportData = try BackupService.shared.exportCards(allCards)
            showingExporter = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            pendingImportURL = url
            showingImportModeSheet = true
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func performImport(mode: ImportMode) {
        guard let url = pendingImportURL else { return }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let backup = try BackupService.shared.parseBackupFile(data)
            importResult = BackupService.shared.importCards(
                from: backup,
                into: modelContext,
                existingCards: allCards,
                mode: mode
            )
            showingImportResult = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        pendingImportURL = nil
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: ArchiveView.archivedCardsPredicate, sort: [
        SortDescriptor(\WordCard.archivedAt, order: .reverse),
        SortDescriptor(\WordCard.updatedAt, order: .reverse),
        SortDescriptor(\WordCard.createdAt, order: .reverse)
    ]) private var archivedCards: [WordCard]

    private static let archivedCardsPredicate = #Predicate<WordCard> { card in
        card.isArchived == true
    }

    var body: some View {
        NavigationStack {
            List {
                if archivedCards.isEmpty {
                    ContentUnavailableView {
                        Label("No Archived Cards", systemImage: "archivebox")
                    } description: {
                        Text("Cards you archive will appear here")
                    }
                } else {
                    ForEach(archivedCards) { card in
                        HStack {
                            CardThumbnailView(card: card)
                                .frame(width: 120, height: 60)
                            VStack(alignment: .leading) {
                                Text(card.text)
                                    .lineLimit(2)
                                if let archivedAt = card.archivedAt {
                                    Text("Archived \(archivedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                card.restore()
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                        .contextMenu {
                            Button {
                                card.restore()
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(card)
                            } label: {
                                Label("Delete Permanently", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Archive")
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
}

struct CardThumbnailView: View {
    let card: WordCard

    var body: some View {
        CardPreviewView(
            text: card.text,
            backgroundColor: Color(hex: card.backgroundColor) ?? .white,
            textColor: Color(hex: card.textColor) ?? .black,
            fontStyle: card.fontStyle,
            cornerRadius: CGFloat(card.cornerRadius),
            borderColor: card.borderColor.flatMap { Color(hex: $0) },
            borderWidth: CGFloat(card.borderWidth)
        )
        .aspectRatio(2, contentMode: .fit)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        CardListView(selectedCard: .constant(nil), showingEditor: .constant(false))
    }
    .modelContainer(for: WordCard.self, inMemory: true)
}
