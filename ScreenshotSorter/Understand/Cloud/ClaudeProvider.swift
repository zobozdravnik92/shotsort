import ClaudeForFoundationModels
import CoreGraphics
import Foundation
import FoundationModels

/// Claude through Anthropic's official Foundation Models package, using the user's own API key.
/// Reuses the same guided-generation type as Apple's on-device model.
struct ClaudeProvider: AIProvider {
    static let modelID = ClaudeModel.haiku5_5.id
    let apiKey: String

    var id: String { CloudProviderKind.claude.providerID }
    var isAvailable: Bool { get async { !apiKey.isEmpty } }

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        // Low effort keeps sorting fast and cheap; the task is simple.
        let model = ClaudeLanguageModel(name: .haiku5_5, auth: .apiKey(apiKey), fixedEffort: .low)
        let session = LanguageModelSession(model: model, instructions: CloudPrompt.instructions)
        do {
            let response = try await session.respond(to: Prompt(CloudPrompt.userMessage(text)), generating: GeneratedCloudExtraction.self)
            var extraction = response.content.sorted.extraction
            if extraction.url == nil { extraction.url = Extraction.firstURL(in: text) }
            extraction = extraction.cleaned()
            extraction.actions = ItemAction.cleaned(response.content.actions.map(\.action), ocrText: text)
            return extraction
        } catch ClaudeError.missingCredential {
            throw CloudError.unauthorized("Claude")
        } catch let error as LanguageModelError {
            if case .rateLimited = error { throw CloudError.rateLimited("Claude") }
            throw error
        }
    }
}

// MARK: - Guided generation types for Boost

/// What Boost asks a cloud model for: the same sorting as on the phone, plus suggested next steps.
@Generable
struct GeneratedCloudExtraction {
    var sorted: GeneratedExtraction

    @Guide(description: "Up to 3 next steps, only when the screenshot clearly supports them. Usually empty.", .maximumCount(3))
    var actions: [GeneratedAction]
}

@Generable
enum GeneratedActionKind {
    case reminder, calendar, draft, open

    var kind: ItemAction.Kind {
        switch self {
        case .reminder: .reminder
        case .calendar: .calendar
        case .draft: .draft
        case .open: .open
        }
    }
}

@Generable
struct GeneratedAction {
    @Guide(description: "reminder: a deadline or return window. calendar: an event with a date. draft: a message to send. open: a link in the screenshot.")
    var kind: GeneratedActionKind

    @Guide(description: "A short button label, such as \"Remind me to apply\".")
    var title: String

    @Guide(description: "YYYY-MM-DD, only when written in the screenshot. Required for reminder and calendar.")
    var date: String?

    @Guide(description: "For draft: the message text. For open: the web address.")
    var detail: String?

    var action: ItemAction {
        ItemAction(kind: kind.kind, title: title, date: date, detail: detail)
    }
}
