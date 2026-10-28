import Foundation
import SwiftData

/// What ingest learned about one screenshot before it's stored.
struct Capture: Sendable {
    var assetID: String
    var createdAt: Date
    var ocrText: String
    var imageHash: String
    var fileSize: Int
}

/// Saving and queries. Every function takes the context it should use,
/// so the same code runs on the main context and the ingest actor.
enum ItemStore {
    /// How much of the text must match for two same-hash screenshots to count as duplicates.
    static let duplicateTextThreshold = 0.9

    static func knownAssetIDs(in context: ModelContext) throws -> Set<String> {
        var descriptor = FetchDescriptor<Screenshot>()
        descriptor.propertiesToFetch = [\.assetID]
        return Set(try context.fetch(descriptor).map(\.assetID))
    }

    /// If the capture is an exact duplicate of a stored screenshot, attaches it to that item and returns the item.
    static func attachIfDuplicate(_ capture: Capture, in context: ModelContext) throws -> Item? {
        guard !capture.imageHash.isEmpty else { return nil }
        let hash = capture.imageHash
        let matches = try context.fetch(FetchDescriptor<Screenshot>(predicate: #Predicate { $0.imageHash == hash }))
        let match = matches.first { candidate in
            guard let item = candidate.item, item.status != .deleted else { return false }
            return TextSimilarity.jaccard(candidate.ocrText, capture.ocrText) >= duplicateTextThreshold
        }
        guard let item = match?.item else { return nil }
        let screenshot = makeScreenshot(capture)
        context.insert(screenshot)
        item.screenshots.append(screenshot)
        if capture.createdAt > item.savedAt { item.savedAt = capture.createdAt }
        return item
    }

    @discardableResult
    static func insert(_ capture: Capture, extraction: Extraction, providerID: String, in context: ModelContext) -> Item {
        let item = Item(
            category: extraction.category,
            title: extraction.title,
            summary: extraction.summary,
            fields: extraction.fields,
            url: extraction.url,
            processedBy: providerID,
            savedAt: capture.createdAt,
            confidence: extraction.confidence
        )
        context.insert(item)
        let screenshot = makeScreenshot(capture)
        context.insert(screenshot)
        item.screenshots.append(screenshot)
        return item
    }

    private static func makeScreenshot(_ capture: Capture) -> Screenshot {
        Screenshot(
            assetID: capture.assetID,
            createdAt: capture.createdAt,
            ocrText: capture.ocrText,
            imageHash: capture.imageHash,
            fileSize: capture.fileSize,
            processedAt: .now
        )
    }

    /// Unreviewed items, newest first, optionally in one category.
    static func newItems(category: ItemCategory?, in context: ModelContext) -> [Item] {
        let newRaw = ItemStatus.new.rawValue
        let sort = [SortDescriptor(\Item.savedAt, order: .reverse)]
        let descriptor: FetchDescriptor<Item>
        if let category {
            let categoryRaw = category.rawValue
            descriptor = FetchDescriptor(predicate: #Predicate { $0.statusRaw == newRaw && $0.categoryRaw == categoryRaw }, sortBy: sort)
        } else {
            descriptor = FetchDescriptor(predicate: #Predicate { $0.statusRaw == newRaw }, sortBy: sort)
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func stats(in context: ModelContext) -> Stats {
        if let existing = try? context.fetch(FetchDescriptor<Stats>()).first { return existing }
        let stats = Stats()
        context.insert(stats)
        return stats
    }

    static func markKept(_ item: Item, in context: ModelContext) {
        guard item.status != .kept else { return }
        if item.status == .new { stats(in: context).totalReviewed += 1 }
        item.status = .kept
        item.reviewedAt = .now
        try? context.save()
    }

    /// Deletes queued in a triage session that never finished (for example, the app was closed) go back to the pile.
    static func resetInterruptedDeletes(in context: ModelContext) {
        let queuedRaw = ItemStatus.queuedForDelete.rawValue
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.statusRaw == queuedRaw })
        guard let stuck = try? context.fetch(descriptor), !stuck.isEmpty else { return }
        for item in stuck {
            item.status = .new
            item.reviewedAt = nil
        }
        try? context.save()
    }

    /// Removes all items and screenshots so they get processed again. Keeps stats.
    static func wipeItems(in context: ModelContext) {
        for item in (try? context.fetch(FetchDescriptor<Item>())) ?? [] { context.delete(item) }
        for screenshot in (try? context.fetch(FetchDescriptor<Screenshot>())) ?? [] { context.delete(screenshot) }
        try? context.save()
    }

    static func wipeAll(in context: ModelContext) {
        wipeItems(in: context)
        for stats in (try? context.fetch(FetchDescriptor<Stats>())) ?? [] { context.delete(stats) }
        try? context.save()
    }
}
