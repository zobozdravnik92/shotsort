import Foundation
import SwiftData
import Testing
@testable import ScreenshotSorter

@MainActor
struct DuplicateMergeTests {
    @Test func sameHashAndTextMergesIntoOneItem() throws {
        let context = try makeTestContext()
        let first = ItemStore.insert(makeCapture("a"), extraction: sampleExtraction, providerID: "test", in: context)
        try context.save()

        let merged = try ItemStore.attachIfDuplicate(makeCapture("b"), in: context)
        try context.save()

        #expect(merged === first)
        #expect(first.screenshots.count == 2)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Screenshot>()) == 2)
    }

    @Test func sameHashWithDifferentTextStaysSeparate() throws {
        let context = try makeTestContext()
        ItemStore.insert(makeCapture("a"), extraction: sampleExtraction, providerID: "test", in: context)
        try context.save()

        let other = makeCapture("b", text: "Staff engineer at Northwind, remote, platform team")
        #expect(try ItemStore.attachIfDuplicate(other, in: context) == nil)
    }

    @Test func differentHashStaysSeparate() throws {
        let context = try makeTestContext()
        ItemStore.insert(makeCapture("a"), extraction: sampleExtraction, providerID: "test", in: context)
        try context.save()

        #expect(try ItemStore.attachIfDuplicate(makeCapture("b", hash: "ffff"), in: context) == nil)
    }

    @Test func emptyHashNeverMerges() throws {
        let context = try makeTestContext()
        ItemStore.insert(makeCapture("a", hash: ""), extraction: sampleExtraction, providerID: "test", in: context)
        try context.save()

        #expect(try ItemStore.attachIfDuplicate(makeCapture("b", hash: ""), in: context) == nil)
    }

    @Test func deletedItemsDontAbsorbDuplicates() throws {
        let context = try makeTestContext()
        let first = ItemStore.insert(makeCapture("a"), extraction: sampleExtraction, providerID: "test", in: context)
        first.status = .deleted
        try context.save()

        #expect(try ItemStore.attachIfDuplicate(makeCapture("b"), in: context) == nil)
    }

    @Test func mergeMovesItemDateToNewestScreenshot() throws {
        let context = try makeTestContext()
        let old = Date(timeIntervalSince1970: 1_000)
        let new = Date(timeIntervalSince1970: 2_000)
        let first = ItemStore.insert(makeCapture("a", createdAt: old), extraction: sampleExtraction, providerID: "test", in: context)
        try context.save()

        _ = try ItemStore.attachIfDuplicate(makeCapture("b", createdAt: new), in: context)
        #expect(first.savedAt == new)
    }
}
