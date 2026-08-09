import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ImageCardLayoutMode: String, CaseIterable {
    case masonry = "Masonry Grid"
    case grid = "Standard Grid"
    case list = "List View"

    var iconName: String {
        switch self {
        case .masonry: return "rectangle.grid.3x2"
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

enum ImageCardSortOrder: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case recentlyUpdated = "Recently Updated"
    case alphabetical = "Title A-Z"
}

struct ImageCardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCards: [ImageCard]

    @Binding var selectedCard: ImageCard?
    @Binding var showingEditor: Bool

    @AppStorage("imageCardLayoutMode") private var layoutMode: ImageCardLayoutMode = .masonry
    @AppStorage("imageCardSortOrder") private var sortOrder: ImageCardSortOrder = .newestFirst

    @State private var searchText = ""
    @State private var selectedCategory: ImageCategory? = nil
    @State private var showingArchive = false
    @State private var editingCard: ImageCard?
    @State private var pasteToastMessage: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isTargetedForDrop = false
    @State private var showingDedupeConfirm = false

    private var activeCards: [ImageCard] {
        allCards.filter { !$0.isArchived }
    }

    private var filteredCards: [ImageCard] {
        var cards = activeCards

        if let category = selectedCategory {
            cards = cards.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            cards = cards.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOrder {
        case .newestFirst:
            return cards.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return cards.sorted { $0.createdAt < $1.createdAt }
        case .recentlyUpdated:
            return cards.sorted { $0.updatedAt > $1.updatedAt }
        case .alphabetical:
            return cards.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Filter Pills
            categoryFilterBar

            // Main Content Area
            Group {
                if filteredCards.isEmpty {
                    emptyStateView
                } else {
                    switch layoutMode {
                    case .masonry:
                        masonryView
                    case .grid:
                        gridView
                    case .list:
                        listView
                    }
                }
            }
        }
        .navigationTitle("Image Cards")
        .searchable(text: $searchText, prompt: "Search title, notes, or tags...")
        .onDrop(of: [.image, .fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if isTargetedForDrop {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                        Text("Drop Images to Create Cards")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = pasteToastMessage {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85), in: Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste Clipboard", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command])
                .help("Paste image from clipboard (Cmd+V)")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            ToolbarItem(placement: .secondaryAction) {
                moreMenu
            }
        }
        .sheet(isPresented: $showingArchive) {
            ImageArchiveView()
        }
        .sheet(item: $editingCard) { card in
            NavigationStack {
                ImageCardEditorView(card: card)
            }
            #if os(macOS)
            .frame(minWidth: 520, minHeight: 620)
            #endif
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    iconName: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(ImageCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        title: cat.displayName,
                        iconName: cat.iconName,
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.secondary.opacity(0.05))
    }

    private var masonryView: some View {
        ScrollView {
            MasonryGrid(
                items: filteredCards,
                minimumColumnWidth: 240,
                spacing: 16,
                itemAspectRatio: { $0.aspectRatio }
            ) { card in
                Button {
                    selectedCard = card
                } label: {
                    ImageCardPreviewView(card: card)
                        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    cardContextMenu(card)
                }
            }
            .padding()
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 320))], spacing: 16) {
                ForEach(filteredCards) { card in
                    Button {
                        selectedCard = card
                    } label: {
                        ImageCardPreviewView(card: card)
                            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        cardContextMenu(card)
                    }
                }
            }
            .padding()
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredCards) { card in
                Button {
                    selectedCard = card
                } label: {
                    HStack(spacing: 14) {
                        ImageCardPreviewView(card: card, showTitleOverlay: false, showValenceBadge: false)
                            .frame(width: 80, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title.isEmpty ? "Image Card" : card.title)
                                .font(.headline)
                            if !card.notes.isEmpty {
                                Text(card.notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Text("\(Int(card.imageWidth))×\(Int(card.imageHeight)) px • \(card.category.displayName)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    cardContextMenu(card)
                }
            }
            .onDelete(perform: archiveCards)
        }
    }

    @ViewBuilder
    private func cardContextMenu(_ card: ImageCard) -> some View {
        Button {
            if let data = card.imageData {
                ClipboardImageService.copyToClipboard(imageData: data)
                showToast("Copied image to clipboard")
            }
        } label: {
            Label("Copy Image", systemImage: "doc.on.doc")
        }

        Button {
            editingCard = card
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
            archiveCard(card)
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Image Cards", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Paste an image from your clipboard (Cmd+V), drag & drop image files, or tap + to create a card")
        } actions: {
            HStack(spacing: 12) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingEditor = true
                } label: {
                    Label("Create Card", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            Menu("Layout Mode") {
                ForEach(ImageCardLayoutMode.allCases, id: \.self) { mode in
                    Button {
                        layoutMode = mode
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                            if layoutMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Menu("Sort By") {
                ForEach(ImageCardSortOrder.allCases, id: \.self) { order in
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
            }

            Divider()

            Button {
                showingArchive = true
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            Text("ImageCard 2.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    private func pasteFromClipboard() {
        if let info = ClipboardImageService.fetchImageFromClipboard() {
            let card = ImageCard(
                title: info.sourceDescription,
                imageData: info.data,
                imageWidth: info.width,
                imageHeight: info.height,
                category: selectedCategory ?? .inspiration
            )
            modelContext.insert(card)
            selectedCard = card
            showToast("📋 Pasted image card (\(Int(info.width)) × \(Int(info.height)) px)")
        } else {
            showToast("⚠️ No image found in clipboard")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            #if os(macOS)
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let nsImg = image as? NSImage,
                       let data = nsImg.tiffRepresentation,
                       let info = ClipboardImageService.processImageData(data) {
                        DispatchQueue.main.async {
                            let card = ImageCard(title: info.sourceDescription, imageData: info.data, imageWidth: info.width, imageHeight: info.height)
                            self.modelContext.insert(card)
                            self.showToast("Dropped image card created")
                        }
                    }
                }
                handled = true
            }
            #else
            if provider.canLoadObject(ofClass: UIImage.self) {
                _ = provider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let uiImg = image as? UIImage,
                       let data = uiImg.jpegData(compressionQuality: 0.9),
                       let info = ClipboardImageService.processImageData(data) {
                        DispatchQueue.main.async {
                            let card = ImageCard(title: info.sourceDescription, imageData: info.data, imageWidth: info.width, imageHeight: info.height)
                            self.modelContext.insert(card)
                            self.showToast("Dropped image card created")
                        }
                    }
                }
                handled = true
            }
            #endif
        }
        return handled
    }

    private func archiveCard(_ card: ImageCard) {
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

    private func showToast(_ text: String) {
        withAnimation {
            pasteToastMessage = text
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                withAnimation {
                    pasteToastMessage = nil
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .bold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct ImageArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [ImageCard]

    private var archivedCards: [ImageCard] {
        allCards.filter { $0.isArchived }
            .sorted { ($0.archivedAt ?? $0.updatedAt) > ($1.archivedAt ?? $1.updatedAt) }
    }

    var body: some View {
        NavigationStack {
            List {
                if archivedCards.isEmpty {
                    ContentUnavailableView {
                        Label("No Archived Cards", systemImage: "archivebox")
                    } description: {
                        Text("Archived image cards will appear here")
                    }
                } else {
                    ForEach(archivedCards) { card in
                        HStack(spacing: 12) {
                            ImageCardPreviewView(card: card, showTitleOverlay: false, showValenceBadge: false)
                                .frame(width: 80, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.title.isEmpty ? "Image Card" : card.title)
                                    .font(.headline)
                                if let archivedAt = card.archivedAt {
                                    Text("Archived \(archivedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()

                            Button {
                                card.restore()
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            modelContext.delete(archivedCards[idx])
                        }
                    }
                }
            }
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
