import Foundation

/// Checks a key with a free "list models" call and picks the model Boost will use.
enum KeyTester {
    /// Returns the model ID to use.
    static func test(_ kind: CloudProviderKind, credential: String, session: URLSession = .shared) async throws -> String {
        switch kind {
        case .claude:
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
            request.setValue(credential, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            _ = try await send(request, name: kind.name, session: session)
            return ClaudeProvider.modelID

        case .openAI, .chatGPT:
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
            request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
            let data = try await send(request, name: kind.name, session: session)
            let list = try JSONDecoder().decode(OpenAIModelList.self, from: data)
            guard let model = ModelPicker.openAI(list.data.map(\.id)) else { throw CloudError.noModel(kind.name) }
            return model

        case .gemini:
            var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000")!)
            request.setValue(credential, forHTTPHeaderField: "x-goog-api-key")
            let data = try await send(request, name: kind.name, session: session)
            let list = try JSONDecoder().decode(GeminiModelList.self, from: data)
            let usable = list.models
                .filter { $0.supportedGenerationMethods?.contains("generateContent") ?? false }
                .map(\.name)
            guard let model = ModelPicker.gemini(usable) else { throw CloudError.noModel(kind.name) }
            return model
        }
    }

    private static func send(_ request: URLRequest, name: String, session: URLSession) async throws -> Data {
        var request = request
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw CloudError.from(status: status, body: data, provider: name) }
        return data
    }

    private struct OpenAIModelList: Decodable {
        struct Model: Decodable { let id: String }
        let data: [Model]
    }

    private struct GeminiModelList: Decodable {
        struct Model: Decodable {
            let name: String
            let supportedGenerationMethods: [String]?
        }
        let models: [Model]
    }
}

/// Picks a fast, cheap model from what a key can access. Sorting doesn't need the biggest model.
enum ModelPicker {
    private static let openAIExcluded = ["audio", "realtime", "transcribe", "tts", "search", "image", "codex", "instruct", "embedding"]
    private static let geminiExcluded = ["image", "tts", "live", "embedding", "audio", "thinking"]

    static func openAI(_ ids: [String]) -> String? {
        let candidates = ids
            .filter { $0.hasPrefix("gpt-") && !openAIExcluded.contains(where: $0.contains) }
            .sorted(by: newestFirst)
        return candidates.first { $0.contains("mini") && !isDated($0) }
            ?? candidates.first { $0.contains("mini") }
            ?? candidates.first { !isDated($0) }
            ?? candidates.first
    }

    static func gemini(_ names: [String]) -> String? {
        let candidates = names
            .map { $0.hasPrefix("models/") ? String($0.dropFirst("models/".count)) : $0 }
            .filter { $0.hasPrefix("gemini-") && !geminiExcluded.contains(where: $0.contains) }
            .sorted(by: newestFirst)
        let stable = candidates.filter { !$0.contains("preview") && !$0.contains("exp") }
        return stable.first { $0.contains("flash") }
            ?? candidates.first { $0.contains("flash") }
            ?? stable.first
            ?? candidates.first
    }

    private static func newestFirst(_ a: String, _ b: String) -> Bool {
        a.localizedStandardCompare(b) == .orderedDescending
    }

    /// Snapshot IDs like "gpt-5-mini-2025-08-07".
    private static func isDated(_ id: String) -> Bool {
        id.range(of: #"\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }
}
