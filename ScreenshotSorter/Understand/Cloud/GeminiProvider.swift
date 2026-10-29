import CoreGraphics
import Foundation

/// Gemini's generateContent API with a response schema, using the user's Google AI Studio key.
struct GeminiProvider: AIProvider {
    let apiKey: String
    let model: String
    var session: URLSession = .shared

    var id: String { CloudProviderKind.gemini.providerID }
    var isAvailable: Bool { get async { !apiKey.isEmpty } }

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw CloudError.noModel("Gemini")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try CloudPrompt.jsonBody([
            "systemInstruction": ["parts": [["text": CloudPrompt.instructions]]],
            "contents": [["role": "user", "parts": [["text": CloudPrompt.userMessage(text)]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": CloudPrompt.geminiSchema,
                "temperature": 0.2,
            ],
        ])

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw CloudError.from(status: status, body: data, provider: "Gemini") }
        let json = try Self.text(fromResponse: data)
        return try CloudPrompt.parse(json, ocrText: text, providerName: "Gemini")
    }

    /// Pulls the reply text out of a generateContent response.
    static func text(fromResponse data: Data) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CloudError.badReply("Gemini")
        }
        let parts = (object["candidates"] as? [[String: Any]])?.first
            .flatMap { $0["content"] as? [String: Any] }
            .flatMap { $0["parts"] as? [[String: Any]] } ?? []
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw CloudError.emptyReply("Gemini") }
        return text
    }
}
