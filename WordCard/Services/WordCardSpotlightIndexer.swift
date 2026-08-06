#if !os(tvOS)
import Foundation
import SwiftData
import CoreSpotlight

/// Donates WordCard entities to Spotlight so individual cards are findable in
/// system search.
///
/// On iOS 18 and later we index `IndexedEntity` values directly, which lets
/// Spotlight reuse the App Intents metadata and resolve results back to cards.
/// macOS uses classic `CSSearchableItem` indexing so system Spotlight gets
/// explicit item metadata independent of App Intents donation behavior.
enum WordCardSpotlightIndexer {

    /// A named, app-specific index (Apple recommends against the default index
    /// for production content).
    static let indexName = "WordCardEntities"

    private static var index: CSSearchableIndex {
        CSSearchableIndex(name: indexName)
    }

    private static func searchableItem(for entity: WordCardEntity) -> CSSearchableItem {
        CSSearchableItem(
            uniqueIdentifier: entity.id.uuidString,
            domainIdentifier: indexName,
            attributeSet: entity.attributeSet
        )
    }

    /// Re-donates every active card, replacing the previous index contents.
    /// Best-effort: failures are logged but never surfaced to the user.
    static func reindexAll() async {
        guard let container = await MainActor.run(body: { SharedModelContainer.container as ModelContainer? }) else { return }

        await Task.detached(priority: .utility) {
            do {
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<WordCard>()
                let entities = try context.fetch(descriptor)
                    .filter { !$0.isArchived }
                    .map(WordCardEntity.init)

                try await index.deleteAllSearchableItems()
                guard !entities.isEmpty else { return }

                #if os(macOS)
                try await index.indexSearchableItems(entities.map(searchableItem))
                #else
                if #available(iOS 18.0, visionOS 2.0, *) {
                    try await index.indexAppEntities(entities)
                } else {
                    try await index.indexSearchableItems(entities.map(searchableItem))
                }
                #endif
            } catch {
                print("⚠️ Spotlight reindex failed: \(error)")
            }
        }.value
    }


    /// Adds or updates a single card in the index (e.g. right after creation).
    static func index(_ entity: WordCardEntity) async {
        do {
            #if os(macOS)
            try await index.indexSearchableItems([searchableItem(for: entity)])
            #else
            if #available(iOS 18.0, visionOS 2.0, *) {
                try await index.indexAppEntities([entity])
            } else {
                try await index.indexSearchableItems([searchableItem(for: entity)])
            }
            #endif
        } catch {
            print("⚠️ Spotlight index of card failed: \(error)")
        }
    }
}
#endif

