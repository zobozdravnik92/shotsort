import CoreGraphics
import Foundation

/// No AI: keyword rules on the OCR text pick a category, and the first meaningful line becomes the title.
/// Used on iPhones without Apple Intelligence, when the model fails, and in tests.
struct FallbackProvider: AIProvider {
    static let id = "fallback"
    var id: String { Self.id }
    var isAvailable: Bool { get async { true } }

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        Self.classify(text)
    }

    /// Phrases that suggest each category. A category needs at least two hits.
    static let keywords: [ItemCategory: [String]] = [
        .jobs: ["apply", "hiring", "job", "salary", "full-time", "full time", "part-time", "years of experience",
                "responsibilities", "requirements", "qualifications", "recruiter", "position", "remote", "hybrid",
                "on-site", "benefits"],
        .posts: ["repost", "comments", "likes", "retweet", "see more", "…more", "thread", "replies", "linkedin", "· follow"],
        .people: ["connections", "connect", "mutual", "followers", "following", "profile", "founder", "works at",
                  "open to work", "message"],
        .inspiration: ["sign up", "get started", "pricing", "per month", "/mo", "onboarding", "continue with",
                       "log in", "free trial", "upgrade"],
        .shopping: ["add to cart", "add to bag", "buy now", "in stock", "free shipping", "free delivery", "reviews",
                    "sold by", "size", "checkout"],
        .receipts: ["total", "subtotal", "receipt", "invoice", "vat", "amount due", "order number", "transaction",
                    "paid", "payment method"],
        .conversations: ["imessage", "delivered", "typing", "whatsapp", "today", "yesterday", "read", "sent", "seen",
                         "online"],
    ]

    static func classify(_ text: String) -> Extraction {
        let lines = meaningfulLines(in: text)
        let category = category(for: text)
        // Skip one-word lines such as an app's header ("LinkedIn", "Receipt") when a fuller line follows.
        let titleIndex = lines.firstIndex { $0.split(separator: " ").count >= 2 } ?? 0
        let title = lines.indices.contains(titleIndex) ? lines[titleIndex] : "Screenshot"
        let rest = lines.indices.contains(titleIndex) ? lines[(titleIndex + 1)...] : []
        let summary = Extraction.truncate(rest.prefix(2).joined(separator: " "), to: 160)
        return Extraction(
            category: category,
            title: title,
            summary: summary,
            fields: fields(for: category, text: text),
            url: Extraction.firstURL(in: text),
            confidence: category == .other ? 0.2 : 0.4
        ).cleaned()
    }

    static func category(for text: String) -> ItemCategory {
        let lower = text.lowercased()
        var best: (category: ItemCategory, hits: Int) = (.other, 0)
        for category in ItemCategory.allCases {
            guard let phrases = keywords[category] else { continue }
            let hits = phrases.filter { lower.contains($0) }.count
            if hits > best.hits { best = (category, hits) }
        }
        return best.hits >= 2 ? best.category : .other
    }

    /// Lines that read like words, skipping status-bar noise such as "9:41" or "5G 87%".
    static func meaningfulLines(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                let letters = line.filter(\.isLetter).count
                return letters >= 4 && Double(letters) / Double(line.count) >= 0.5
            }
    }

    static func fields(for category: ItemCategory, text: String) -> [String: String] {
        let lower = text.lowercased()
        switch category {
        case .jobs:
            if lower.contains("hybrid") { return ["remote": "hybrid"] }
            if lower.contains("remote") { return ["remote": "yes"] }
            if lower.contains("on-site") || lower.contains("onsite") { return ["remote": "no"] }
            return [:]
        case .receipts:
            // Prefer the line with the total over subtotals and line items.
            let totalLine = text.split(whereSeparator: \.isNewline).first { line in
                let lower = line.lowercased()
                return lower.contains("total") && !lower.contains("subtotal") && firstAmount(in: String(line)) != nil
            }
            return (totalLine.flatMap { firstAmount(in: String($0)) } ?? firstAmount(in: text)).map { ["amount": $0] } ?? [:]
        case .shopping:
            return firstAmount(in: text).map { ["price": $0] } ?? [:]
        default:
            return [:]
        }
    }

    static func firstAmount(in text: String) -> String? {
        let pattern = /[€$£]\s?\d+(?:[.,]\d{2})?|\d+[.,]\d{2}\s?[€$£]/
        return text.firstMatch(of: pattern).map { String($0.output) }
    }
}
