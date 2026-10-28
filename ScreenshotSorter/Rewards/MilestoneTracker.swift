import Foundation

enum Milestone: Equatable, Sendable {
    case streak(Int)
    case spaceFreed(bytes: Int)
    case allClear(ItemCategory)

    var message: String { RewardCopy.message(for: self) }
}

/// Decides when a moment is earned (spec §8, Phase 1). Each milestone fires once per session.
struct MilestoneTracker {
    static let streakThresholds = [10, 25, 50, 100, 250]
    static let spaceThresholds = [100_000_000, 500_000_000, 1_000_000_000]

    private var celebratedStreaks: Set<Int> = []
    private var clearedCategories: Set<ItemCategory> = []

    /// Keeps and deletes both count toward the streak.
    mutating func recordStreak(_ streak: Int) -> Milestone? {
        guard Self.streakThresholds.contains(streak), celebratedStreaks.insert(streak).inserted else { return nil }
        return .streak(streak)
    }

    mutating func allClear(_ category: ItemCategory) -> Milestone? {
        clearedCategories.insert(category).inserted ? .allClear(category) : nil
    }

    /// The biggest space threshold crossed by a committed delete, if any.
    static func spaceMilestone(from before: Int, to after: Int) -> Milestone? {
        guard let threshold = spaceThresholds.last(where: { before < $0 && $0 <= after }) else { return nil }
        return .spaceFreed(bytes: threshold)
    }
}
