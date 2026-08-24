import Foundation
import SwiftData
import os

/// Re-queues ImageCards that the CloudKit exporter no longer considers dirty.
///
/// Before the move to iCloud.mjbernaski.imagecard.app, ModelConfiguration was
/// built without a `cloudKitDatabase:` argument, so SwiftData defaulted to
/// `.automatic` and mirrored into WordCard's container. Those rows accumulated
/// export metadata against that container and still carry it, so
/// PFCloudKitExporter reports "Found 0 objects needing export" for every card
/// predating the move — it believes they are already uploaded, to a database
/// this app no longer talks to. Cards created after the move export normally,
/// which is why sync looks alive while nothing old ever reaches another device.
///
/// Re-queuing them takes a genuine value change: assigning a property to the
/// value it already holds marks the context dirty and saves, but the exporter
/// still skips the row, so the write has to move the stored value. Nudging
/// updatedAt by a second and putting it straight back leaves every card exactly
/// as it was while producing two real history transactions, which is what the
/// exporter scans. If the second save is ever lost, the damage is a one-second
/// timestamp, not lost card data.
enum ImageCardCloudKitBackfill {
    /// Bump the version suffix to force the backfill to run again.
    private static let defaultsKey = "ImageCardCloudKitBackfill.v2.completed"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "mjbernaski.imagecard.app",
        category: "CloudKit"
    )

    /// Logs what the store actually holds, on every launch.
    ///
    /// The CloudKit logs report records moving without saying what landed, so
    /// an import that adds cards and one that re-applies records this device
    /// already had read identically. The list view also hides archived cards,
    /// which makes "nothing arrived" and "it arrived archived" look the same
    /// on screen. This distinguishes all three.
    static func logInventory(in context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<ImageCard>())
            let archived = all.filter(\.isArchived).count
            logger.info("Store holds \(all.count) cards, \(archived) of them archived")
        } catch {
            logger.error("Inventory FAILED: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func runIfNeeded(in context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: defaultsKey) else { return }

        do {
            let cards = try context.fetch(FetchDescriptor<ImageCard>())
            guard !cards.isEmpty else {
                // Nothing to re-queue, but the store is now past the era that
                // produced orphaned rows, so don't check again.
                defaults.set(true, forKey: defaultsKey)
                logger.info("Backfill: store is empty, nothing to re-queue")
                return
            }

            for card in cards {
                card.updatedAt = card.updatedAt.addingTimeInterval(1)
            }
            try context.save()

            for card in cards {
                card.updatedAt = card.updatedAt.addingTimeInterval(-1)
            }
            try context.save()
            defaults.set(true, forKey: defaultsKey)
            logger.info("Backfill: re-queued \(cards.count) cards for CloudKit export")
        } catch {
            logger.error("Backfill FAILED: \(error.localizedDescription, privacy: .public)")
        }
    }
}
