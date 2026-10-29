import Foundation
import Observation

/// Boost state shown in Settings: which providers are connected, which one is used, and the last error.
/// Off by default. Keys are in the Keychain; only on/off, the chosen provider and model IDs are in UserDefaults.
@MainActor
@Observable
final class BoostSettings {
    private enum Key {
        static let enabled = "boost.enabled"
        static let selected = "boost.selected"
        static let modelPrefix = "boost.model."
    }

    private(set) var connected: Set<CloudProviderKind> = []
    private(set) var lastError: String?
    private(set) var lastErrorAt: Date?

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled) }
    }

    var selected: CloudProviderKind? {
        didSet { defaults.set(selected?.rawValue, forKey: Key.selected) }
    }

    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var tokenStore: ChatGPTTokenStore

    init(keychain: KeychainStore = KeychainStore(), defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults
        self.tokenStore = ChatGPTTokenStore(keychain: keychain)
        self.isEnabled = defaults.bool(forKey: Key.enabled)
        self.selected = defaults.string(forKey: Key.selected).flatMap(CloudProviderKind.init(rawValue:))
        self.connected = Set(CloudProviderKind.allCases.filter { keychain.read($0.keychainAccount) != nil })
        if let selected, !connected.contains(selected) { self.selected = nil }
    }

    /// Providers shown in Settings. ChatGPT appears once a client ID is configured,
    /// and always in debug builds so the screen can be seen.
    var availableKinds: [CloudProviderKind] {
        #if DEBUG
        CloudProviderKind.allCases
        #else
        CloudProviderKind.allCases.filter { $0 != .chatGPT || ChatGPTConfig.isAvailable }
        #endif
    }

    var isActive: Bool { isEnabled && selected.map(connected.contains) == true }

    func model(for kind: CloudProviderKind) -> String? {
        defaults.string(forKey: Key.modelPrefix + kind.rawValue)
    }

    /// The key as "sk-ant-…3f2a", for display only.
    func maskedCredential(for kind: CloudProviderKind) -> String? {
        guard kind.usesAPIKey, let key = keychain.read(kind.keychainAccount) else { return nil }
        return CloudProviderKind.masked(key)
    }

    /// Tests the key with a free call, then saves it. Throws a `CloudError` the screen can show.
    func connect(_ kind: CloudProviderKind, key: String) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = try await KeyTester.test(kind, credential: trimmed)
        try keychain.save(trimmed, for: kind.keychainAccount)
        didConnect(kind, model: model)
    }

    /// Saves ChatGPT tokens after sign-in and picks a model the plan can use.
    func connectChatGPT(_ tokens: ChatGPTTokens) async throws {
        let model = try await KeyTester.test(.chatGPT, credential: tokens.accessToken)
        ChatGPTTokenStore.save(tokens, to: keychain)
        tokenStore = ChatGPTTokenStore(keychain: keychain)
        didConnect(.chatGPT, model: model)
    }

    func disconnect(_ kind: CloudProviderKind) {
        keychain.delete(kind.keychainAccount)
        defaults.removeObject(forKey: Key.modelPrefix + kind.rawValue)
        connected.remove(kind)
        if selected == kind { selected = connected.sorted { $0.rawValue < $1.rawValue }.first }
        if connected.isEmpty { isEnabled = false }
    }

    func recordError(_ message: String) {
        lastError = message
        lastErrorAt = .now
    }

    func clearError() {
        lastError = nil
        lastErrorAt = nil
    }

    /// The cloud model to use right now, or nil when Boost is off or not set up.
    func makeCloudProvider() -> (any AIProvider)? {
        guard isActive, let kind = selected else { return nil }
        switch kind {
        case .claude:
            return keychain.read(kind.keychainAccount).map { ClaudeProvider(apiKey: $0) }
        case .gemini:
            guard let key = keychain.read(kind.keychainAccount), let model = model(for: kind) else { return nil }
            return GeminiProvider(apiKey: key, model: model)
        case .openAI:
            guard let key = keychain.read(kind.keychainAccount), let model = model(for: kind) else { return nil }
            return OpenAIProvider(model: model, auth: .apiKey(key))
        case .chatGPT:
            guard let model = model(for: kind) else { return nil }
            return OpenAIProvider(model: model, auth: .chatGPT(tokenStore))
        }
    }

    private func didConnect(_ kind: CloudProviderKind, model: String) {
        defaults.set(model, forKey: Key.modelPrefix + kind.rawValue)
        connected.insert(kind)
        if selected == nil || !connected.contains(selected!) { selected = kind }
        clearError()
    }
}
