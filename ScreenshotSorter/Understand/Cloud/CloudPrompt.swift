import Foundation

/// What every cloud provider is asked, and how its JSON reply becomes an `Extraction`.
/// Only screenshot text is ever sent, never images (spec §11).
enum CloudPrompt {
    static let instructions = """
    You sort iPhone screenshots. You get the text read from one screenshot.
    Pick the single best category: jobs (job posts, hiring), posts (social posts, ideas, articles, threads), \
    people (profiles, contacts), inspiration (UI and design references), shopping (products, ads with prices), \
    receipts (receipts, tickets, documents), conversations (chats, messages, notifications), or other.
    Write a short title (at most 60 characters) and a one- or two-sentence summary in plain words.
    Title rules: jobs = the role; posts = the idea in one line; people = the person's name; inspiration = what it shows; \
    shopping = the product; receipts = the merchant or document; conversations = who and about what.
    Fields, only when visible: jobs: company, location, remote (yes, no or hybrid), salary, seniority. \
    posts: author, platform, topic. people: title, company, whySaved. inspiration: source, element, style. \
    shopping: price, store. receipts: amount, date. conversations: app.
    Never guess and never write "N/A". Ignore status bars, app chrome and button labels.
    Write in the same language as the screenshot. Confidence is how sure you are about the category, from 0 to 1.
    """

    /// Caps what's sent so one long screenshot can't run up a bill.
    static let maxCharacters = 4_000

    static func userMessage(_ text: String) -> String {
        let trimmed = String(text.prefix(maxCharacters))
        return "Text read from the screenshot:\n\(trimmed.isEmpty ? "(no readable text)" : trimmed)"
    }

    static let categories = ItemCategory.allCases.map(\.rawValue)

    /// OpenAI structured outputs (strict JSON Schema).
    static var openAISchema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "category": ["type": "string", "enum": categories],
                "title": ["type": "string"],
                "summary": ["type": "string"],
                "fields": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": ["key": ["type": "string"], "value": ["type": "string"]],
                        "required": ["key", "value"],
                    ],
                ],
                "url": ["type": ["string", "null"]],
                "confidence": ["type": "number"],
            ],
            "required": ["category", "title", "summary", "fields", "url", "confidence"],
        ]
    }

    /// Gemini response schema (OpenAPI subset).
    static var geminiSchema: [String: Any] {
        [
            "type": "OBJECT",
            "properties": [
                "category": ["type": "STRING", "enum": categories],
                "title": ["type": "STRING"],
                "summary": ["type": "STRING"],
                "fields": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": ["key": ["type": "STRING"], "value": ["type": "STRING"]],
                        "required": ["key", "value"],
                    ],
                ],
                "url": ["type": "STRING", "nullable": true],
                "confidence": ["type": "NUMBER"],
            ],
            "required": ["category", "title", "summary", "fields", "confidence"],
            "propertyOrdering": ["category", "title", "summary", "fields", "url", "confidence"],
        ]
    }

    private struct Reply: Decodable {
        struct Field: Decodable {
            let key: String
            let value: String
        }
        let category: String
        let title: String
        let summary: String
        let fields: [Field]?
        let url: String?
        let confidence: Double?
    }

    /// Turns a provider's JSON text into a cleaned `Extraction`.
    static func parse(_ json: String, ocrText: String, providerName: String) throws -> Extraction {
        guard let data = json.data(using: .utf8), let reply = try? JSONDecoder().decode(Reply.self, from: data) else {
            throw CloudError.badReply(providerName)
        }
        var fields: [String: String] = [:]
        for field in reply.fields ?? [] where fields[field.key] == nil { fields[field.key] = field.value }
        let extraction = Extraction(
            category: ItemCategory(rawValue: reply.category.lowercased()) ?? .other,
            title: reply.title,
            summary: reply.summary,
            fields: fields,
            url: reply.url ?? Extraction.firstURL(in: ocrText),
            confidence: reply.confidence ?? 0.8
        )
        return extraction.cleaned()
    }

    static func jsonBody(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }
}
