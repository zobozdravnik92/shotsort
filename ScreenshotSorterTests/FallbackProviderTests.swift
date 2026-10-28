import Testing
@testable import ScreenshotSorter

struct FallbackProviderTests {
    @Test func jobPostIsSortedIntoJobs() {
        let text = """
        9:41
        Senior Product Designer
        Acme Pay · Berlin (Hybrid)
        Full-time · 5+ years of experience
        Apply now
        Requirements
        """
        let extraction = FallbackProvider.classify(text)
        #expect(extraction.category == .jobs)
        #expect(extraction.title == "Senior Product Designer")
        #expect(extraction.fields["remote"] == "hybrid")
    }

    @Test func receiptIsSortedIntoReceipts() {
        let text = """
        Receipt #1234
        Subtotal €20.00
        VAT €3.40
        Total €23.40
        """
        let extraction = FallbackProvider.classify(text)
        #expect(extraction.category == .receipts)
        #expect(extraction.fields["amount"] == "€23.40")
    }

    @Test func textWithoutKeywordsIsOther() {
        #expect(FallbackProvider.category(for: "Hello there, nice weather") == .other)
    }

    @Test func oneKeywordIsNotEnough() {
        #expect(FallbackProvider.category(for: "We are hiring") == .other)
    }

    @Test func titleSkipsStatusBarNoise() {
        let text = "9:41\n5G 87%\nMeaningful line here\nSecond line"
        #expect(FallbackProvider.classify(text).title == "Meaningful line here")
    }

    @Test func titleSkipsOneWordAppHeader() {
        let text = "9:41\nLinkedIn\nSenior Product Designer\nAcme Pay · Berlin"
        let extraction = FallbackProvider.classify(text)
        #expect(extraction.title == "Senior Product Designer")
        #expect(extraction.summary == "Acme Pay · Berlin")
    }

    @Test func oneWordLinesStillGiveATitle() {
        #expect(FallbackProvider.classify("Weather\nLjubljana").title == "Weather")
    }

    @Test func longTitleIsCutTo60Characters() {
        let long = String(repeating: "Design ", count: 20)
        let title = FallbackProvider.classify(long).title
        #expect(title.count == Extraction.maxTitleLength)
        #expect(title.hasSuffix("…"))
    }

    @Test func emptyTextGetsPlaceholderTitle() {
        let extraction = FallbackProvider.classify("")
        #expect(extraction.category == .other)
        #expect(extraction.title == "Screenshot")
    }

    @Test func cleanedDropsPlaceholdersAndOtherCategoriesFields() {
        let raw = Extraction(
            category: .jobs,
            title: "Designer",
            summary: "",
            fields: ["Company": "Acme", "salary": "N/A", "author": "Someone"],
            url: "none",
            confidence: 1.4
        )
        let cleaned = raw.cleaned()
        #expect(cleaned.fields == ["company": "Acme"])
        #expect(cleaned.url == nil)
        #expect(cleaned.confidence == 1)
    }
}
