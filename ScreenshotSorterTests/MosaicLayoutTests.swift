import Testing
@testable import ScreenshotSorter

struct MosaicLayoutTests {
    private func summary(_ category: ItemCategory, _ screenshots: Int, items: Int? = nil) -> CategorySummary {
        CategorySummary(category: category, itemCount: items ?? screenshots, screenshotCount: screenshots, unreviewedCount: 0)
    }

    @Test func singleCategoryIsFullWidth() {
        let result = MosaicLayout.layout([summary(.jobs, 3)])
        #expect(result.hero?.summary.category == .jobs)
        #expect(result.left.isEmpty && result.right.isEmpty)
    }

    @Test func dominantCategoryGetsTheFullWidthCard() {
        let result = MosaicLayout.layout([summary(.jobs, 3), summary(.other, 14), summary(.posts, 1), summary(.people, 1)])
        #expect(result.hero?.summary.category == .other)
        #expect(result.left.count + result.right.count == 3)
    }

    @Test func evenPilesShareTwoColumns() {
        let result = MosaicLayout.layout([summary(.jobs, 5), summary(.posts, 5), summary(.people, 5), summary(.shopping, 5)])
        #expect(result.hero == nil)
        #expect(result.left.count == 2 && result.right.count == 2)
        #expect(Set((result.left + result.right).map(\.height)) == [MosaicLayout.maxHeight])
    }

    @Test func biggerPilesGetTallerCards() {
        let small = MosaicLayout.height(for: 1, maxCount: 10)
        let medium = MosaicLayout.height(for: 5, maxCount: 10)
        let large = MosaicLayout.height(for: 10, maxCount: 10)
        #expect(small < medium && medium < large)
        #expect(large == MosaicLayout.maxHeight)
        #expect(MosaicLayout.height(for: 0, maxCount: 10) == MosaicLayout.minHeight)
    }

    @Test func sizeFollowsScreenshotsNotItems() {
        // One job post captured across 6 screenshots outweighs 3 single-screenshot posts.
        let result = MosaicLayout.layout([summary(.jobs, 6, items: 1), summary(.posts, 3, items: 3), summary(.people, 5), summary(.shopping, 5)])
        #expect(result.hero == nil)
        let tiles = result.left + result.right
        let jobs = tiles.first { $0.summary.category == .jobs }
        let posts = tiles.first { $0.summary.category == .posts }
        #expect((jobs?.height ?? 0) > (posts?.height ?? .infinity))
    }

    @Test func emptyCategoriesAreSkipped() {
        let result = MosaicLayout.layout([summary(.jobs, 0), summary(.posts, 2)])
        #expect(result.hero?.summary.category == .posts)
        #expect(result.left.isEmpty && result.right.isEmpty)
    }

    @Test func columnsStayBalanced() {
        let result = MosaicLayout.layout([summary(.jobs, 8), summary(.posts, 7), summary(.people, 6), summary(.shopping, 5), summary(.receipts, 4), summary(.conversations, 3)])
        let left = result.left.reduce(0) { $0 + $1.height }
        let right = result.right.reduce(0) { $0 + $1.height }
        #expect(abs(left - right) <= MosaicLayout.maxHeight)
    }
}
