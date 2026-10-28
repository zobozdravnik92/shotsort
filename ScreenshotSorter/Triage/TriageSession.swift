import Foundation
import Observation
import SwiftData

/// One triage run: the deck, undo history, queued deletes and live counters (spec §7).
@MainActor
@Observable
final class TriageSession {
    enum Decision: Sendable {
        case keep, delete
    }

    struct SessionResult: Identifiable {
        let id = UUID()
        let reviewed: Int
        let deleted: Int
        let bytesFreed: Int
        /// True when the user cancelled the iOS confirmation, so nothing was deleted.
        let deletesCancelled: Bool
        let spaceMilestone: Milestone?
    }

    private struct Swipe {
        let item: Item
        let decision: Decision
    }

    let category: ItemCategory?
    private(set) var deck: [Item]
    private(set) var position = 0
    private(set) var isFinished = false
    private var history: [Swipe] = []
    private var streak = 0
    private var bestStreak = 0
    @ObservationIgnored private var tracker = MilestoneTracker()
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let deleter: any AssetDeleting

    init(category: ItemCategory?, context: ModelContext, deleter: any AssetDeleting) {
        self.category = category
        self.context = context
        self.deleter = deleter
        self.deck = ItemStore.newItems(category: category, in: context)
    }

    var current: Item? { position < deck.count ? deck[position] : nil }
    var upcoming: Item? { position + 1 < deck.count ? deck[position + 1] : nil }
    var reviewedCount: Int { history.count }
    var deletedCount: Int { history.filter { $0.decision == .delete }.count }
    /// Bytes that will be freed once the queued deletes are confirmed.
    var pendingBytes: Int {
        history.filter { $0.decision == .delete }.reduce(0) { $0 + $1.item.totalBytes }
    }
    var canUndo: Bool { !history.isEmpty && !isFinished }

    /// Records a swipe on the current card and returns any milestones it reached.
    @discardableResult
    func swipe(_ decision: Decision) -> [Milestone] {
        guard !isFinished, let item = current else { return [] }
        item.status = decision == .keep ? .kept : .queuedForDelete
        item.reviewedAt = .now
        history.append(Swipe(item: item, decision: decision))
        position += 1
        streak += 1
        bestStreak = max(bestStreak, streak)

        var milestones: [Milestone] = []
        if let milestone = tracker.recordStreak(streak) { milestones.append(milestone) }
        let categoryHasMore = deck[position...].contains { $0.category == item.category }
        if !categoryHasMore, let milestone = tracker.allClear(item.category) { milestones.append(milestone) }
        return milestones
    }

    /// Puts the last card back on top of the deck.
    func undo() {
        guard canUndo, let last = history.popLast() else { return }
        last.item.status = .new
        last.item.reviewedAt = nil
        position -= 1
        streak = max(0, streak - 1)
    }

    /// Commits the session: one delete request for every queued screenshot, then stats.
    /// If the user cancels the iOS confirmation, queued items go back to the pile and nothing counts as deleted.
    func finish() async -> SessionResult {
        guard !isFinished else {
            return SessionResult(reviewed: 0, deleted: 0, bytesFreed: 0, deletesCancelled: false, spaceMilestone: nil)
        }
        isFinished = true

        let queued = history.filter { $0.decision == .delete }.map(\.item)
        let keptCount = history.count - queued.count
        var deleted = 0
        var bytes = 0
        var cancelled = false

        if !queued.isEmpty {
            let ids = queued.flatMap { $0.screenshots.map(\.assetID) }
            let pending = queued.reduce(0) { $0 + $1.totalBytes }
            if await deleter.delete(ids) {
                for item in queued { item.status = .deleted }
                deleted = queued.count
                bytes = pending
            } else {
                for item in queued {
                    item.status = .new
                    item.reviewedAt = nil
                }
                // Counters revert: never show progress that didn't happen.
                history.removeAll { $0.decision == .delete }
                cancelled = true
            }
        }

        let stats = ItemStore.stats(in: context)
        let bytesBefore = stats.bytesFreed
        stats.totalReviewed += keptCount + deleted
        stats.totalDeleted += deleted
        stats.bytesFreed += bytes
        stats.bestStreak = max(stats.bestStreak, bestStreak)
        try? context.save()
        // History stays so the counters keep showing this session's totals behind the summary.

        return SessionResult(
            reviewed: keptCount + deleted,
            deleted: deleted,
            bytesFreed: bytes,
            deletesCancelled: cancelled,
            spaceMilestone: MilestoneTracker.spaceMilestone(from: bytesBefore, to: stats.bytesFreed)
        )
    }
}
