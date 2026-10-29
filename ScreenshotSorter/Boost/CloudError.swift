import Foundation

/// Errors from cloud providers, worded for Settings.
enum CloudError: LocalizedError, Equatable {
    case unauthorized(String)
    case rateLimited(String)
    case planLimitReached
    case notEligible
    case http(String, Int)
    case noModel(String)
    case emptyReply(String)
    case badReply(String)
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .unauthorized(let name): "\(name) didn't accept the key. Check that it's copied in full and still active."
        case .rateLimited(let name): "\(name) is limiting requests, or the account is out of credit."
        case .planLimitReached: "You've reached this app's weekly ChatGPT limit. Raise it in ChatGPT settings or wait until next week."
        case .notEligible: "Using your ChatGPT plan in other apps needs ChatGPT Plus or Pro."
        case .http(let name, let code): "\(name) returned an error (\(code)). Try again later."
        case .noModel(let name): "Couldn't find a suitable \(name) model for this key."
        case .emptyReply(let name): "\(name) sent back an empty reply."
        case .badReply(let name): "\(name) sent back a reply the app couldn't read."
        case .notSignedIn: "Sign in with ChatGPT again in Settings."
        }
    }

    /// Errors that won't fix themselves by retrying, so Boost stops for this run.
    var isPermanent: Bool {
        switch self {
        case .unauthorized, .notEligible, .notSignedIn, .noModel, .planLimitReached: true
        default: false
        }
    }

    /// Maps an HTTP status (and OpenAI's plan-usage error codes) to an error.
    static func from(status: Int, body: Data, provider name: String) -> CloudError {
        let text = String(data: body, encoding: .utf8) ?? ""
        if text.contains("subscription_sharing_usage_limit_exceeded") { return .planLimitReached }
        if text.contains("subscription_sharing_user_not_eligible") { return .notEligible }
        if text.contains("subscription_sharing_invalid_user") { return .notSignedIn }
        switch status {
        case 401, 403: return .unauthorized(name)
        case 429: return .rateLimited(name)
        default: return .http(name, status)
        }
    }
}
