import Foundation

enum RewardCopy {
    static func message(for milestone: Milestone) -> String {
        switch milestone {
        case .streak(let count):
            switch count {
            case 10: return "10 down. You're on a roll."
            case 25: return "25 in a row. Keep it going."
            case 50: return "50 in a row. Your camera roll thanks you."
            case 100: return "100 in a row. Unstoppable."
            default: return "\(count) in a row. Legendary."
            }
        case .spaceFreed(let bytes):
            switch bytes {
            case ..<500_000_000: return "Freed 100 MB. That's a whole album's worth."
            case ..<1_000_000_000: return "Freed 500 MB. That's room for about 150 photos."
            default: return "Freed 1 GB. Welcome to the Gigabyte Club."
            }
        case .allClear(let category):
            return category == .jobs ? "Jobs: all clear. Go apply to something." : "\(category.name): all clear."
        }
    }
}
