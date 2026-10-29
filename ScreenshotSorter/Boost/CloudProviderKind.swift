import Foundation

/// The cloud models Boost can use (spec §12, Phase 4).
enum CloudProviderKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case chatGPT, openAI, claude, gemini

    var id: String { rawValue }

    /// Shown in Settings.
    var name: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .openAI: "OpenAI"
        case .claude: "Claude"
        case .gemini: "Gemini"
        }
    }

    /// Stored on items as `processedBy`.
    var providerID: String {
        switch self {
        case .chatGPT: "chatgpt"
        case .openAI: "openai"
        case .claude: "claude"
        case .gemini: "gemini"
        }
    }

    var usesAPIKey: Bool { self != .chatGPT }

    /// Where people create a key.
    var keysURL: URL? {
        switch self {
        case .chatGPT: nil
        case .openAI: URL(string: "https://platform.openai.com/api-keys")
        case .claude: URL(string: "https://platform.claude.com/settings/keys")
        case .gemini: URL(string: "https://aistudio.google.com/apikey")
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .chatGPT: ""
        case .openAI: "sk-…"
        case .claude: "sk-ant-…"
        case .gemini: "AIza…"
        }
    }

    /// Guesses which provider a pasted key belongs to.
    static func detect(key: String) -> CloudProviderKind? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("sk-ant-") { return .claude }
        if trimmed.hasPrefix("AIza") { return .gemini }
        if trimmed.hasPrefix("sk-") { return .openAI }
        return nil
    }

    static func forProviderID(_ id: String) -> CloudProviderKind? {
        allCases.first { $0.providerID == id }
    }

    /// "sk-ant-…3f2a": enough to recognise a key without showing it.
    static func masked(_ key: String) -> String {
        guard key.count > 10 else { return "••••" }
        let prefix = key.prefix(key.hasPrefix("sk-ant-") ? 7 : 3)
        return "\(prefix)…\(key.suffix(4))"
    }
}
