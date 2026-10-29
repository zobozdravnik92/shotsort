import Foundation

/// What a provider returns for one screenshot (spec §3).
struct Extraction: Sendable, Equatable {
    var category: ItemCategory
    var title: String
    var summary: String
    var fields: [String: String]
    var url: String?
    /// Self-reported, 0–1. Under 0.5 is a candidate for Boost.
    var confidence: Double
    /// The provider that produced this, when it differs from the one that was asked (Boost hands off to the cloud).
    var source: String? = nil

    static let maxTitleLength = 60
    private static let placeholders: Set<String> = ["n/a", "na", "none", "unknown", "not specified", "not visible", "-", "null"]

    /// Applies the spec's limits: short title, only this category's fields, no placeholder values.
    func cleaned() -> Extraction {
        var copy = self
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.title = trimmedTitle.isEmpty ? "Screenshot" : Self.truncate(trimmedTitle, to: Self.maxTitleLength)
        copy.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)

        var cleanFields: [String: String] = [:]
        for (key, value) in fields {
            // Match keys loosely ("Company" → "company") and keep the spec's spelling.
            guard let canonical = category.fieldKeys.first(where: { $0.lowercased() == key.lowercased() }) else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !Self.placeholders.contains(trimmed.lowercased()) else { continue }
            cleanFields[canonical] = trimmed
        }
        copy.fields = cleanFields

        let trimmedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        copy.url = trimmedURL.isEmpty || Self.placeholders.contains(trimmedURL.lowercased()) ? nil : trimmedURL
        copy.confidence = min(max(confidence, 0), 1)
        return copy
    }

    static func truncate(_ text: String, to length: Int) -> String {
        guard text.count > length else { return text }
        return String(text.prefix(length - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// The first web link in some text, if any.
    static func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, options: [], range: range) {
            if let url = match.url, let scheme = url.scheme, scheme.hasPrefix("http") {
                return url.absoluteString
            }
        }
        return nil
    }
}
