import CoreGraphics
import Foundation

/// OpenAI's Responses API with structured output. Works with the user's API key,
/// or with their ChatGPT plan after Sign in with ChatGPT (which requires streaming and no stored state).
struct OpenAIProvider: AIProvider {
    enum Auth: Sendable {
        case apiKey(String)
        case chatGPT(ChatGPTTokenStore)
    }

    let model: String
    let auth: Auth
    var session: URLSession = .shared

    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    var kind: CloudProviderKind {
        if case .chatGPT = auth { return .chatGPT }
        return .openAI
    }

    var id: String { kind.providerID }
    var isAvailable: Bool { get async { true } }

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        let streaming = kind == .chatGPT
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await bearerToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try CloudPrompt.jsonBody([
            "model": model,
            "instructions": CloudPrompt.instructions,
            "input": CloudPrompt.userMessage(text),
            "store": false,
            "stream": streaming,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "screenshot_item",
                    "strict": true,
                    "schema": CloudPrompt.openAISchema,
                ],
            ],
        ])

        let json: String
        if streaming {
            json = try await streamedText(for: request)
        } else {
            let (data, response) = try await session.data(for: request)
            try check(response, body: data)
            json = try Self.outputText(fromResponse: data, providerName: kind.name)
        }
        return try CloudPrompt.parse(json, ocrText: text, providerName: kind.name)
    }

    private func bearerToken() async throws -> String {
        switch auth {
        case .apiKey(let key): key
        case .chatGPT(let tokens): try await tokens.accessToken()
        }
    }

    private func check(_ response: URLResponse, body: Data) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw CloudError.from(status: status, body: body, provider: kind.name) }
    }

    private func streamedText(for request: URLRequest) async throws -> String {
        let (bytes, response) = try await session.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            var body = Data()
            for try await byte in bytes.prefix(4_096) { body.append(byte) }
            throw CloudError.from(status: status, body: body, provider: kind.name)
        }
        var stream = SSEAccumulator(providerName: kind.name)
        for try await line in bytes.lines {
            if try stream.consume(line) { break }
        }
        return try stream.finish()
    }

    /// Pulls the output text out of a non-streamed Responses API reply.
    static func outputText(fromResponse data: Data, providerName: String) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = object["output"] as? [[String: Any]] else { throw CloudError.badReply(providerName) }
        let text = output
            .compactMap { $0["content"] as? [[String: Any]] }
            .flatMap { $0 }
            .filter { ($0["type"] as? String) == "output_text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw CloudError.emptyReply(providerName) }
        return text
    }
}

/// Collects a streamed Responses API reply. A stream can start and then fail, so only `response.completed` counts.
struct SSEAccumulator {
    let providerName: String
    private(set) var text = ""
    private var completed = false

    init(providerName: String) {
        self.providerName = providerName
    }

    /// Returns true when the stream is finished.
    mutating func consume(_ line: String) throws -> Bool {
        guard line.hasPrefix("data:") else { return false }
        let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return true }
        guard let data = payload.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else { return false }
        switch type {
        case "response.output_text.delta":
            text += event["delta"] as? String ?? ""
        case "response.completed":
            completed = true
            return true
        case "response.failed", "error":
            throw CloudError.badReply(providerName)
        default:
            break
        }
        return false
    }

    func finish() throws -> String {
        guard completed else { throw CloudError.badReply(providerName) }
        guard !text.isEmpty else { throw CloudError.emptyReply(providerName) }
        return text
    }
}
