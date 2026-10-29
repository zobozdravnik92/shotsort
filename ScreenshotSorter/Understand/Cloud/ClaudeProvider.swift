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
            let response = try await session.respond(to: Prompt(CloudPrompt.userMessage(text)), generating: GeneratedExtraction.self)
            var extraction = response.content.extraction
            if extraction.url == nil { extraction.url = Extraction.firstURL(in: text) }
            return extraction.cleaned()
        } catch ClaudeError.missingCredential {
            throw CloudError.unauthorized("Claude")
        } catch let error as LanguageModelError {
            if case .rateLimited = error { throw CloudError.rateLimited("Claude") }
            throw error
        }
    }
}
