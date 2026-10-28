import CoreGraphics
import Foundation
import FoundationModels

/// The default provider: Apple's on-device model through the Foundation Models framework.
struct AppleOnDeviceProvider: AIProvider {
    static let id = "apple-on-device"
    var id: String { Self.id }

    var isAvailable: Bool {
        get async { SystemLanguageModel.default.isAvailable }
    }

    /// OCR text sent to the model is capped to keep inside its context window.
    private static let maxCharacters = 3_000
    private static let retryCharacters = 1_000

    private static let instructions = """
    You sort iPhone screenshots. You get the text read from one screenshot, and sometimes the image.
    Pick the single best category. Write a short title and a one- or two-sentence summary in plain words.
    Only fill in details you can actually read in the screenshot. Never guess, and never write "N/A".
    Write in the same language as the screenshot.
    """

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        do {
            return try await run(text: String(text.prefix(Self.maxCharacters)), image: image)
        } catch {
            // Most failures are a full context window or an image the model can't take: retry smaller, text only.
            return try await run(text: String(text.prefix(Self.retryCharacters)), image: nil)
        }
    }

    private func run(text: String, image: CGImage?) async throws -> Extraction {
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: Self.instructions)
        let prompt = Prompt {
            "Text read from the screenshot:"
            text.isEmpty ? "(no readable text)" : text
            if let image {
                Attachment(image)
            }
        }
        let response = try await session.respond(to: prompt, generating: GeneratedExtraction.self)
        var extraction = response.content.extraction
        if extraction.url == nil { extraction.url = Extraction.firstURL(in: text) }
        return extraction.cleaned()
    }
}

// MARK: - Guided generation types

@Generable
enum GeneratedCategory {
    case jobs, posts, people, inspiration, shopping, receipts, conversations, other

    var category: ItemCategory {
        switch self {
        case .jobs: .jobs
        case .posts: .posts
        case .people: .people
        case .inspiration: .inspiration
        case .shopping: .shopping
        case .receipts: .receipts
        case .conversations: .conversations
        case .other: .other
        }
    }
}

@Generable
struct GeneratedField {
    var key: String
    var value: String
}

@Generable
struct GeneratedExtraction {
    @Guide(description: "What kind of screenshot this is: a job post, a social post or idea, a person's profile, design inspiration, a product, a receipt or document, a chat, or other.")
    var category: GeneratedCategory

    @Guide(description: "At most 60 characters. Jobs: the role. Posts: the idea in one line. People: the person's name. Inspiration: what it shows. Shopping: the product. Receipts: the merchant or document. Conversations: who and about what. Other: a short description.")
    var title: String

    @Guide(description: "One or two plain sentences on what the screenshot is about.")
    var summary: String

    @Guide(description: "Details read from the screenshot. Use only these keys. jobs: company, location, remote (yes, no or hybrid), salary, seniority. posts: author, platform, topic. people: title, company, whySaved. inspiration: source, element (onboarding, pricing, nav…), style. shopping: price, store. receipts: amount, date. conversations: app. Leave out anything not visible.")
    var fields: [GeneratedField]

    @Guide(description: "A web address visible in the screenshot, if there is one.")
    var url: String?

    @Guide(description: "How sure you are about the category, from 0 to 1.", .range(0...1))
    var confidence: Double

    var extraction: Extraction {
        Extraction(
            category: category.category,
            title: title,
            summary: summary,
            fields: Dictionary(fields.map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first }),
            url: url,
            confidence: confidence
        )
    }
}
