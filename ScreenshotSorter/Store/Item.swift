import Foundation
import SwiftData

@Model
final class Item {
    @Attribute(.unique) var id: UUID
    // Enums are stored as raw strings so they work in #Predicate.
    var categoryRaw: String
    var title: String
    var summary: String
    var fields: [String: String]
    var url: String?
    @Relationship(deleteRule: .cascade, inverse: \Screenshot.item)
    var screenshots: [Screenshot] = []
    var statusRaw: String
    var reviewedAt: Date?
    /// Provider id, shown in the detail view.
    var processedBy: String
    /// Date of the newest source screenshot, used for sorting.
    var savedAt: Date
    var confidence: Double

    init(
        category: ItemCategory,
        title: String,
        summary: String,
        fields: [String: String] = [:],
        url: String? = nil,
        status: ItemStatus = .new,
        processedBy: String,
        savedAt: Date,
        confidence: Double = 1
    ) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.title = title
        self.summary = summary
        self.fields = fields
        self.url = url
        self.statusRaw = status.rawValue
        self.processedBy = processedBy
        self.savedAt = savedAt
        self.confidence = confidence
    }

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }
}

extension Item {
    static let onDeviceProviders: Set<String> = ["apple-on-device", "fallback"]

    var totalBytes: Int { screenshots.reduce(0) { $0 + $1.fileSize } }

    var sortedScreenshots: [Screenshot] { screenshots.sorted { $0.createdAt < $1.createdAt } }

    var processedInCloud: Bool { !Self.onDeviceProviders.contains(processedBy) }

    /// A tappable web link, adding https:// when the model left the scheme off.
    var link: URL? {
        guard let url, !url.isEmpty else { return nil }
        let candidate = url.contains("://") ? url : "https://" + url
        guard let value = URL(string: candidate), let scheme = value.scheme, scheme.hasPrefix("http") else { return nil }
        return value
    }

    /// A field value ready to show, or nil when it's missing.
    func displayValue(for key: String) -> String? {
        guard let raw = fields[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        guard key == "remote" else { return raw }
        switch raw.lowercased() {
        case "yes": return "Remote"
        case "no": return "On-site"
        case "hybrid": return "Hybrid"
        default: return raw
        }
    }

    var keyFieldValues: [String] { category.keyFields.compactMap { displayValue(for: $0) } }
}
