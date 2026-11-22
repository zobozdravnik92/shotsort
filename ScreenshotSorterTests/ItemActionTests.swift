import Foundation
import SwiftData
import Testing
@testable import ScreenshotSorter

struct ItemActionTests {
    @Test func keepsValidActionsAndDropsBadOnes() {
        let ocr = "Apply by 30 November at jobs.acme.com"
        let actions = ItemAction.cleaned([
            ItemAction(kind: .reminder, title: "Remind me to apply", date: "2026-11-30"),
            ItemAction(kind: .reminder, title: "No date", date: nil),
            ItemAction(kind: .calendar, title: "Impossible date", date: "2026-02-31"),
            ItemAction(kind: .draft, title: "Empty draft", detail: "  "),
            ItemAction(kind: .open, title: "Made-up link", detail: "https://evil.example"),
            ItemAction(kind: .open, title: "Open the job", detail: "https://jobs.acme.com/42"),
            ItemAction(kind: .draft, title: "   ", detail: "Hi"),
        ], ocrText: ocr)
        #expect(actions.map(\.title) == ["Remind me to apply", "Open the job"])
    }

    @Test func keepsAtMostThreeAndNoDuplicates() {
        let draft = ItemAction(kind: .draft, title: "Say hi", detail: "Hi!")
        let actions = ItemAction.cleaned(
            [draft, draft] + (1...5).map { ItemAction(kind: .draft, title: "Draft \($0)", detail: "Text") },
            ocrText: ""
        )
        #expect(actions.count == ItemAction.maxCount)
        #expect(actions.filter { $0 == draft }.count == 1)
    }

    @Test func shortensLongText() {
        let long = String(repeating: "a", count: 200)
        let action = ItemAction.cleaned([ItemAction(kind: .draft, title: long, detail: long)], ocrText: "").first
        #expect(action?.title.count == ItemAction.maxTitleLength)
    }

    @Test func parsesActionsFromCloudReply() throws {
        let json = """
        {"category":"jobs","title":"Designer","summary":"","fields":[],"url":null,"confidence":0.9,
         "actions":[{"kind":"reminder","title":"Remind me to apply","date":"2026-11-30","detail":null},
                    {"kind":"teleport","title":"Unknown kind","date":null,"detail":null}]}
        """
        let extraction = try CloudPrompt.parse(json, ocrText: "Apply by 30 November", providerName: "Test")
        #expect(extraction.actions == [ItemAction(kind: .reminder, title: "Remind me to apply", date: "2026-11-30")])
    }

    @Test func replyWithoutActionsStillParses() throws {
        let json = #"{"category":"posts","title":"Idea","summary":"","fields":[],"url":null,"confidence":0.7}"#
        #expect(try CloudPrompt.parse(json, ocrText: "", providerName: "Test").actions.isEmpty)
    }

    @MainActor
    @Test func itemStoresAndRemovesActions() throws {
        let context = try makeTestContext()
        let item = Item(category: .jobs, title: "Designer", summary: "", processedBy: "claude", savedAt: .now)
        context.insert(item)
        let reminder = ItemAction(kind: .reminder, title: "Apply", date: "2026-11-30")
        let draft = ItemAction(kind: .draft, title: "Intro", detail: "Hi")
        item.actions = [reminder, draft]
        #expect(item.actions == [reminder, draft])

        item.removeAction(reminder)
        #expect(item.actions == [draft])

        item.markDeleted()
        #expect(item.actions.isEmpty)
    }
}

struct BoostPlanTests {
    @Test func plansRankAndMapToProducts() {
        #expect(BoostPlan.free < .boost && BoostPlan.boost < .superboost)
        #expect(BoostPlan.forProductID("com.rokpremuz.ScreenshotSorter.superboost.monthly") == .superboost)
        #expect(BoostPlan.forProductID("com.rokpremuz.ScreenshotSorter.skin.retro") == nil)
        #expect(BoostPlan.paid.allSatisfy { $0.productID != nil && !$0.features.isEmpty })
    }
}
