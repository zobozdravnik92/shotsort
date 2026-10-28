import Foundation

/// Word overlap between two OCR texts, from 0 (nothing shared) to 1 (same words).
enum TextSimilarity {
    static func words(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 3 }
        )
    }

    static func jaccard(_ first: String, _ second: String) -> Double {
        let a = words(in: first)
        let b = words(in: second)
        if a.isEmpty && b.isEmpty { return 1 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }
}
