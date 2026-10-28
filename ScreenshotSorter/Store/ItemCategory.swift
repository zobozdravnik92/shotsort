import Foundation

/// The fixed base types every item belongs to (spec §5).
/// Named `ItemCategory` because `Category` clashes with an Objective-C runtime type.
enum ItemCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case jobs, posts, people, inspiration, shopping, receipts, conversations, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .jobs: "Jobs"
        case .posts: "Posts and ideas"
        case .people: "People"
        case .inspiration: "Inspiration"
        case .shopping: "Shopping"
        case .receipts: "Receipts and docs"
        case .conversations: "Conversations"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .jobs: "briefcase"
        case .posts: "lightbulb"
        case .people: "person.crop.circle"
        case .inspiration: "paintpalette"
        case .shopping: "bag"
        case .receipts: "doc.text"
        case .conversations: "bubble.left.and.bubble.right"
        case .other: "square.grid.2x2"
        }
    }

    /// Every field this category can carry, in display order.
    var fieldKeys: [String] {
        switch self {
        case .jobs: ["company", "location", "remote", "salary", "seniority"]
        case .posts: ["author", "platform", "topic"]
        case .people: ["title", "company", "whySaved"]
        case .inspiration: ["source", "element", "style"]
        case .shopping: ["price", "store"]
        case .receipts: ["amount", "date"]
        case .conversations: ["app"]
        case .other: []
        }
    }

    /// The two or three fields shown as chips in lists.
    var keyFields: [String] {
        switch self {
        case .jobs: ["company", "remote", "salary"]
        case .posts: ["author", "platform"]
        case .people: ["title", "company"]
        case .inspiration: ["source", "element"]
        case .shopping: ["price", "store"]
        case .receipts: ["amount", "date"]
        case .conversations: ["app"]
        case .other: []
        }
    }

    static func fieldLabel(_ key: String) -> String {
        switch key {
        case "whySaved": "Why saved"
        case "remote": "Remote"
        default: key.prefix(1).uppercased() + key.dropFirst()
        }
    }
}

enum ItemStatus: String, Codable, Sendable {
    case new, kept, queuedForDelete, deleted
}
