import Foundation
import SwiftData
import Testing
@testable import ScreenshotSorter

@MainActor
struct ItemSearchTests {
    private func item(_ title: String, summary: String = "", ocr: String = "", status: ItemStatus = .new,
                      fields: [String: String] = [:], daysAgo: Double = 0, in context: ModelContext) -> Item {
        let item = Item(category: .jobs, title: title, summary: summary, fields: fields, status: status,
                        processedBy: "fallback", savedAt: Date(timeIntervalSinceNow: -daysAgo * 86_400))
        context.insert(item)
        let shot = Screenshot(assetID: UUID().uuidString, createdAt: .now, ocrText: ocr, imageHash: "", fileSize: 0)
        context.insert(shot)
        shot.item = item
        return item
    }

    @Test func emptyQueryFindsNothing() throws {
        let context = try makeTestContext()
        let items = [item("Designer", in: context)]
        #expect(ItemSearch.search("   ", in: items).isEmpty)
    }

    @Test func everyWordMustMatchIgnoringCaseAndAccents() throws {
        let context = try makeTestContext()
        let cafe = item("Café in Ljubljana", in: context)
        let other = item("Café in Berlin", in: context)
        let results = ItemSearch.search("CAFE ljubljana", in: [cafe, other])
        #expect(results.map(\.item.id) == [cafe.id])
    }

    @Test func titleMatchesComeFirstThenNewest() throws {
        let context = try makeTestContext()
        let inText = item("Job post", ocr: "Looking for a designer", daysAgo: 0, in: context)
        let olderTitle = item("Designer at Acme", daysAgo: 5, in: context)
        let newerTitle = item("Designer at Playlist", daysAgo: 1, in: context)
        let results = ItemSearch.search("designer", in: [inText, olderTitle, newerTitle])
        #expect(results.map(\.item.id) == [newerTitle.id, olderTitle.id, inText.id])
    }

    @Test func screenshotTextMatchShowsTheLine() throws {
        let context = try makeTestContext()
        let found = item("Job post", ocr: "Header\nApply by 30 November\nFooter", in: context)
        let result = try #require(ItemSearch.search("november", in: [found]).first)
        #expect(result.snippet == "Apply by 30 November")
    }

    @Test func titleMatchHasNoSnippet() throws {
        let context = try makeTestContext()
        let found = item("Designer", ocr: "Designer wanted", in: context)
        #expect(ItemSearch.search("designer", in: [found]).first?.snippet == nil)
    }

    @Test func findsFieldsAndCategoryName() throws {
        let context = try makeTestContext()
        let found = item("Role", fields: ["company": "Acme"], in: context)
        #expect(ItemSearch.search("acme", in: [found]).count == 1)
        #expect(ItemSearch.search("jobs", in: [found]).count == 1)
    }

    @Test func skipsDeletedItems() throws {
        let context = try makeTestContext()
        let gone = item("Designer", status: .deleted, in: context)
        #expect(ItemSearch.search("designer", in: [gone]).isEmpty)
    }
}
