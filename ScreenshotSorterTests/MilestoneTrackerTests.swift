import Foundation
import Photos
import Testing
@testable import ScreenshotSorter

struct MilestoneTrackerTests {
    @Test func streakMilestonesFireAtTheThresholds() {
        var tracker = MilestoneTracker()
        let fired = (1...300).compactMap { tracker.recordStreak($0) }
        #expect(fired == [.streak(10), .streak(25), .streak(50), .streak(100), .streak(250)])
    }

    @Test func streakMilestoneDoesNotRepeatAfterUndo() {
        var tracker = MilestoneTracker()
        #expect(tracker.recordStreak(10) == .streak(10))
        // Undo drops the streak to 9; swiping again reaches 10 a second time.
        #expect(tracker.recordStreak(10) == nil)
    }

    @Test func spaceMilestoneFiresWhenAThresholdIsCrossed() {
        #expect(MilestoneTracker.spaceMilestone(from: 90_000_000, to: 120_000_000) == .spaceFreed(bytes: 100_000_000))
    }

    @Test func spaceMilestoneUsesTheBiggestThresholdCrossed() {
        #expect(MilestoneTracker.spaceMilestone(from: 0, to: 600_000_000) == .spaceFreed(bytes: 500_000_000))
    }

    @Test func noSpaceMilestoneWithoutCrossing() {
        #expect(MilestoneTracker.spaceMilestone(from: 100_000_000, to: 200_000_000) == nil)
        #expect(MilestoneTracker.spaceMilestone(from: 0, to: 99_000_000) == nil)
    }

    @Test func allClearFiresOncePerCategory() {
        var tracker = MilestoneTracker()
        #expect(tracker.allClear(.jobs) == .allClear(.jobs))
        #expect(tracker.allClear(.jobs) == nil)
        #expect(tracker.allClear(.posts) == .allClear(.posts))
    }

    @Test func copyMatchesTheSpec() {
        #expect(Milestone.streak(10).message == "10 down. You're on a roll.")
        #expect(Milestone.streak(50).message == "50 in a row. Your camera roll thanks you.")
        #expect(Milestone.allClear(.jobs).message == "Jobs: all clear. Go apply to something.")
    }
}

@MainActor
struct TriageMilestoneTests {
    @Test func clearingTheLastItemOfACategoryIsAllClear() throws {
        let context = try makeTestContext()
        for index in 0..<2 {
            let capture = makeCapture("j\(index)", hash: "h\(index)", createdAt: Date(timeIntervalSince1970: Double(1_000 - index)))
            ItemStore.insert(capture, extraction: sampleExtraction, providerID: "test", in: context)
        }
        try context.save()
        let session = TriageSession(category: nil, context: context, deleter: FakeDeleter(confirms: true))

        #expect(session.swipe(.keep).isEmpty)
        #expect(session.swipe(.delete) == [.allClear(.jobs)])
    }
}

@MainActor
struct CongratsPopupTests {
    @Test func tenthSortShowsTheCongratsPopup() throws {
        let context = try makeTestContext()
        for index in 0..<12 {
            let extraction = Extraction(category: index.isMultiple(of: 2) ? .jobs : .posts, title: "Item \(index)", summary: "", fields: [:], url: nil, confidence: 1)
            let capture = makeCapture("c\(index)", hash: "h\(index)", createdAt: Date(timeIntervalSince1970: Double(1_000 - index)))
            ItemStore.insert(capture, extraction: extraction, providerID: "test", in: context)
        }
        try context.save()
        let session = TriageSession(category: nil, context: context, deleter: FakeDeleter(confirms: true))

        for _ in 0..<9 {
            #expect(!session.swipe(.keep).contains { $0.isCelebration })
        }
        let tenth = session.swipe(.delete)
        #expect(tenth.contains(.streak(10)))
        #expect(tenth.allSatisfy { $0.isCelebration })
        #expect(session.reviewedCount == 10)
    }
}

struct NewScreenshotAlertTests {
    @Test func notifiesOnlyWithFullAccessAlertsOnAndNewScreenshots() {
        #expect(NewScreenshots.shouldNotify(access: .authorized, alertsOn: true, newCount: 3))
        #expect(!NewScreenshots.shouldNotify(access: .limited, alertsOn: true, newCount: 3))
        #expect(!NewScreenshots.shouldNotify(access: .authorized, alertsOn: false, newCount: 3))
        #expect(!NewScreenshots.shouldNotify(access: .authorized, alertsOn: true, newCount: 0))
    }

    @Test func notificationTextCountsScreenshots() {
        #expect(NewScreenshots.notificationText(newCount: 1).body == "1 new screenshot is sorted and ready to triage.")
        #expect(NewScreenshots.notificationText(newCount: 4).body == "4 new screenshots are sorted and ready to triage.")
    }
}
