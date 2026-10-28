import Foundation
import SwiftData

/// Lifetime counters. There is only ever one row.
@Model
final class Stats {
    var totalReviewed: Int = 0
    var totalDeleted: Int = 0
    var bytesFreed: Int = 0
    var bestStreak: Int = 0
    var achievements: [String] = []

    init() {}
}
