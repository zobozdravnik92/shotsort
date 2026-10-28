import Foundation
import SwiftData
import Testing
@testable import ScreenshotSorter

@MainActor
struct DeleteQueueTests {
    /// Three new jobs items, one screenshot each, 1 MB per screenshot.
    private func seed(_ context: ModelContext, count: Int = 3, category: ItemCategory = .jobs) throws -> [Item] {
        var items: [Item] = []
        for index in 0..<count {
            let extraction = Extraction(category: category, title: "Item \(index)", summary: "", fields: [:], url: nil, confidence: 1)
            let capture = makeCapture("\(category.rawValue)-\(index)", hash: "h\(index)", createdAt: Date(timeIntervalSince1970: Double(1_000 - index)))
            items.append(ItemStore.insert(capture, extraction: extraction, providerID: "test", in: context))
        }
        try context.save()
        return items
    }

    @Test func confirmedDeletesAreCommittedInOneRequest() async throws {
        let context = try makeTestContext()
        let items = try seed(context)
        let deleter = FakeDeleter(confirms: true)
        let session = TriageSession(category: nil, context: context, deleter: deleter)

        session.swipe(.keep)
        session.swipe(.delete)
        session.swipe(.delete)
        #expect(session.pendingBytes == 2_000_000)

        let result = await session.finish()

        #expect(result.reviewed == 3)
        #expect(result.deleted == 2)
        #expect(result.bytesFreed == 2_000_000)
        #expect(!result.deletesCancelled)
        #expect(await deleter.calls.count == 1)
        #expect(Set(await deleter.calls.first ?? []) == ["jobs-1", "jobs-2"])
        #expect(items[0].status == .kept)
        #expect(items[1].status == .deleted)
        #expect(items[2].status == .deleted)

        let stats = ItemStore.stats(in: context)
        #expect(stats.totalReviewed == 3)
        #expect(stats.totalDeleted == 2)
        #expect(stats.bytesFreed == 2_000_000)
    }

    @Test func cancelledConfirmationPutsItemsBack() async throws {
        let context = try makeTestContext()
        let items = try seed(context)
        let session = TriageSession(category: nil, context: context, deleter: FakeDeleter(confirms: false))

        session.swipe(.delete)
        session.swipe(.delete)
        let result = await session.finish()

        #expect(result.deletesCancelled)
        #expect(result.deleted == 0)
        #expect(result.reviewed == 0)
        #expect(result.bytesFreed == 0)
        #expect(items[0].status == .new)
        #expect(items[1].status == .new)
        #expect(items[0].reviewedAt == nil)
        #expect(session.deletedCount == 0)
        #expect(session.pendingBytes == 0)

        let stats = ItemStore.stats(in: context)
        #expect(stats.totalDeleted == 0)
        #expect(stats.bytesFreed == 0)
    }

    @Test func keepsOnlyNeverAskToDelete() async throws {
        let context = try makeTestContext()
        _ = try seed(context, count: 2)
        let deleter = FakeDeleter(confirms: true)
        let session = TriageSession(category: nil, context: context, deleter: deleter)

        session.swipe(.keep)
        session.swipe(.keep)
        let result = await session.finish()

        #expect(result.reviewed == 2)
        #expect(await deleter.calls.isEmpty)
    }

    @Test func undoRestoresTheLastCard() throws {
        let context = try makeTestContext()
        let items = try seed(context)
        let session = TriageSession(category: nil, context: context, deleter: FakeDeleter(confirms: true))

        session.swipe(.delete)
        #expect(session.current === items[1])
        session.undo()

        #expect(session.current === items[0])
        #expect(items[0].status == .new)
        #expect(session.deletedCount == 0)
        #expect(session.pendingBytes == 0)
        #expect(!session.canUndo)
    }

    @Test func deckHoldsOnlyNewItemsOfTheChosenCategory() throws {
        let context = try makeTestContext()
        let jobs = try seed(context, count: 2, category: .jobs)
        _ = try seed(context, count: 2, category: .posts)
        jobs[0].status = .kept
        try context.save()

        let session = TriageSession(category: .jobs, context: context, deleter: FakeDeleter(confirms: true))
        #expect(session.deck.count == 1)
        #expect(session.deck.first === jobs[1])
    }

    @Test func interruptedSessionIsResetOnLaunch() throws {
        let context = try makeTestContext()
        let items = try seed(context, count: 1)
        let session = TriageSession(category: nil, context: context, deleter: FakeDeleter(confirms: true))
        session.swipe(.delete)
        try context.save()

        ItemStore.resetInterruptedDeletes(in: context)
        #expect(items[0].status == .new)
    }
}
