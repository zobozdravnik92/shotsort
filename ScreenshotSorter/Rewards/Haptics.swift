import UIKit

/// Light for keep, medium for delete, success pattern on milestones (spec §7).
@MainActor
enum Haptics {
    static func keep() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func delete() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func milestone() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
