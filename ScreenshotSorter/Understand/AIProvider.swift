import CoreGraphics

/// Turns one screenshot's text (and optionally its image) into a structured item.
protocol AIProvider: Sendable {
    /// "apple-on-device", "fallback", later "claude", "openai", "gemini".
    var id: String { get }
    var isAvailable: Bool { get async }
    func extract(text: String, image: CGImage?) async throws -> Extraction
}
