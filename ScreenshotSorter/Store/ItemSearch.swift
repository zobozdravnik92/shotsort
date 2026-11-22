import Foundation

/// Finds items by their title, summary, details, link, category, or any text read from their screenshots.
/// Runs on the phone; nothing is sent anywhere.
enum ItemSearch {
    struct Result {
        let item: Item
        /// The matching line from the screenshot text, when the match isn't in the title or summary.
        let snippet: String?
    }

    /// Every word of the query must appear somewhere in the item. Ignores case and accents.
    /// Best matches first (title, then summary and details, then screenshot text), newest first within each.
    static func search(_ query: String, in items: [Item]) -> [Result] {
        let words = normalize(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }

        let scored: [(result: Result, score: Int)] = items.compactMap { item in
            guard item.status != .deleted else { return nil }
            let title = normalize(item.title)
            let details = normalize(([item.summary, item.url ?? "", item.category.name] + item.fields.values).joined(separator: " "))
            let ocr = item.sortedScreenshots.map(\.ocrText).joined(separator: "\n")
            let ocrNormalized = normalize(ocr)

            var score = 0
            for word in words {
                if title.contains(word) { score += 3 }
                else if details.contains(word) { score += 2 }
                else if ocrNormalized.contains(word) { score += 1 }
                else { return nil }
            }
            let inTitleOrDetails = words.allSatisfy { title.contains($0) || details.contains($0) }
            let snippet = inTitleOrDetails ? nil : self.snippet(in: ocr, for: words)
            return (Result(item: item, snippet: snippet), score)
        }

        let ranked = scored.sorted { (a: (result: Result, score: Int), b: (result: Result, score: Int)) -> Bool in
            if a.score != b.score { return a.score > b.score }
            return a.result.item.savedAt > b.result.item.savedAt
        }
        return ranked.map(\.result)
    }

    /// The first line of screenshot text that holds a query word, trimmed to a readable length.
    static func snippet(in text: String, for words: [String]) -> String? {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let line = lines.first(where: { line in words.contains { normalize(line).contains($0) } }) else { return nil }
        return Extraction.truncate(line, to: 90)
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
