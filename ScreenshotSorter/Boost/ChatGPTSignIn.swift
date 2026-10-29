import CryptoKit
import Foundation

/// Sign in with ChatGPT. Commercial apps need a client ID from OpenAI (interest form, limited trial).
/// Until `clientID` is set, the option stays hidden in Settings.
enum ChatGPTConfig {
    /// Paste the client ID from OpenAI here once approved.
    static let clientID: String? = nil
    static let callbackScheme = "shotsort"
    static let redirectURI = "shotsort://chatgpt-callback"
    static let scopes = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"
    static let resource = "https://api.openai.com/v1"
    static let discoveryURL = URL(string: "https://auth.openai.com/.well-known/openid-configuration")!

    static var isAvailable: Bool { !(clientID ?? "").isEmpty }
}

struct ChatGPTTokens: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
}

/// OAuth 2.0 authorization code flow with PKCE. Endpoints come from OpenAI's discovery document.
struct ChatGPTSignIn: Sendable {
    struct Request: Sendable {
        let url: URL
        let state: String
        let verifier: String
        let tokenEndpoint: URL
    }

    private struct Discovery: Decodable {
        let authorization_endpoint: URL
        let token_endpoint: URL
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Double?
    }

    var session: URLSession = .shared

    /// Builds the sign-in page URL. Open it with `WebAuthenticationSession`.
    func makeRequest() async throws -> Request {
        guard let clientID = ChatGPTConfig.clientID, !clientID.isEmpty else { throw CloudError.notSignedIn }
        let (data, _) = try await session.data(from: ChatGPTConfig.discoveryURL)
        let discovery = try JSONDecoder().decode(Discovery.self, from: data)
        let verifier = Self.randomURLSafe(bytes: 48)
        let state = Self.randomURLSafe(bytes: 24)
        var components = URLComponents(url: discovery.authorization_endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: ChatGPTConfig.redirectURI),
            URLQueryItem(name: "scope", value: ChatGPTConfig.scopes),
            URLQueryItem(name: "resource", value: ChatGPTConfig.resource),
            URLQueryItem(name: "code_challenge", value: Self.challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return Request(url: components.url!, state: state, verifier: verifier, tokenEndpoint: discovery.token_endpoint)
    }

    /// Exchanges the callback for tokens after checking `state`.
    func complete(_ request: Request, callback: URL) async throws -> ChatGPTTokens {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == request.state,
              let code = items.first(where: { $0.name == "code" })?.value else { throw CloudError.notSignedIn }
        return try await tokenRequest(request.tokenEndpoint, form: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": ChatGPTConfig.redirectURI,
            "client_id": ChatGPTConfig.clientID ?? "",
            "code_verifier": request.verifier,
        ], previousRefresh: nil)
    }

    func refresh(_ tokens: ChatGPTTokens) async throws -> ChatGPTTokens {
        guard let refreshToken = tokens.refreshToken else { throw CloudError.notSignedIn }
        let (data, _) = try await session.data(from: ChatGPTConfig.discoveryURL)
        let discovery = try JSONDecoder().decode(Discovery.self, from: data)
        return try await tokenRequest(discovery.token_endpoint, form: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": ChatGPTConfig.clientID ?? "",
        ], previousRefresh: refreshToken)
    }

    private func tokenRequest(_ endpoint: URL, form: [String: String], previousRefresh: String?) async throws -> ChatGPTTokens {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw CloudError.notSignedIn }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        return ChatGPTTokens(
            accessToken: token.access_token,
            // Refresh tokens rotate; keep the old one only if a new one wasn't sent.
            refreshToken: token.refresh_token ?? previousRefresh,
            expiresAt: Date.now.addingTimeInterval(token.expires_in ?? 3_600)
        )
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func randomURLSafe(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64URL(Data(bytes))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Hands out a fresh ChatGPT access token, refreshing and saving to the Keychain as needed.
actor ChatGPTTokenStore {
    private let keychain: KeychainStore
    private let signIn: ChatGPTSignIn
    private var tokens: ChatGPTTokens?

    init(keychain: KeychainStore = KeychainStore(), signIn: ChatGPTSignIn = ChatGPTSignIn()) {
        self.keychain = keychain
        self.signIn = signIn
        self.tokens = Self.load(from: keychain)
    }

    func accessToken() async throws -> String {
        guard var current = tokens else { throw CloudError.notSignedIn }
        if current.expiresAt.timeIntervalSinceNow < 60 {
            do {
                current = try await signIn.refresh(current)
                tokens = current
                Self.save(current, to: keychain)
            } catch {
                throw CloudError.notSignedIn
            }
        }
        return current.accessToken
    }

    static func load(from keychain: KeychainStore) -> ChatGPTTokens? {
        guard let json = keychain.read(CloudProviderKind.chatGPT.keychainAccount) else { return nil }
        return try? JSONDecoder().decode(ChatGPTTokens.self, from: Data(json.utf8))
    }

    static func save(_ tokens: ChatGPTTokens, to keychain: KeychainStore) {
        guard let data = try? JSONEncoder().encode(tokens), let json = String(data: data, encoding: .utf8) else { return }
        try? keychain.save(json, for: CloudProviderKind.chatGPT.keychainAccount)
    }
}
