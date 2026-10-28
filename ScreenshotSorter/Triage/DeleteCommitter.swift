import Foundation
import SwiftData

protocol AssetDeleting: Sendable {
    /// Deletes the assets. Returns false if the user cancels the system confirmation or deleting fails.
    func delete(_ assetIDs: [String]) async -> Bool
}

/// Sends each asset to the source that owns it. Photos assets go in one request, so iOS asks once.
struct DeleteCommitter: AssetDeleting {
    let sources: [any ScreenshotSource]

    func delete(_ assetIDs: [String]) async -> Bool {
        guard !assetIDs.isEmpty else { return true }
        var allDeleted = true
        for source in sources {
            let owned = assetIDs.filter { source.owns($0) }
            guard !owned.isEmpty else { continue }
            let deleted = await source.delete(owned)
            if !deleted { allDeleted = false }
        }
        return allDeleted
    }

    /// Deletes one item's screenshots right away (from the detail screen) and updates stats.
    @MainActor
    static func deleteItem(_ item: Item, deleter: any AssetDeleting, context: ModelContext) async -> Bool {
        let ids = item.screenshots.map(\.assetID)
        let bytes = item.totalBytes
        let wasNew = item.status == .new
        guard await deleter.delete(ids) else { return false }
        item.status = .deleted
        item.reviewedAt = .now
        let stats = ItemStore.stats(in: context)
        stats.totalDeleted += 1
        stats.bytesFreed += bytes
        if wasNew { stats.totalReviewed += 1 }
        try? context.save()
        return true
    }
}
