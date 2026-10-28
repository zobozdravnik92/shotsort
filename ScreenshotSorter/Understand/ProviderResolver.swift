import FoundationModels

/// Picks the provider at launch: Apple's model when it's ready, otherwise keyword rules with a notice.
enum ProviderResolver {
    struct Resolution: Sendable {
        let provider: any AIProvider
        /// Shown on Home when the app falls back to keyword rules.
        let notice: String?
    }

    static func resolve() -> Resolution {
        let availability = SystemLanguageModel.default.availability
        if case .available = availability {
            return Resolution(provider: AppleOnDeviceProvider(), notice: nil)
        }
        return Resolution(provider: FallbackProvider(), notice: notice(for: availability))
    }

    private static func notice(for availability: SystemLanguageModel.Availability) -> String {
        guard case .unavailable(let reason) = availability else {
            return "Smart sorting isn't available right now, so the app uses simple keyword rules."
        }
        switch reason {
        case .deviceNotEligible:
            return "This iPhone can't run Apple Intelligence, so the app sorts with simple keyword rules and summaries are basic."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings for smarter sorting and summaries. Until then, the app uses simple keyword rules."
        case .modelNotReady:
            return "Apple Intelligence is still getting ready. The app uses simple keyword rules for now."
        @unknown default:
            return "Smart sorting isn't available right now, so the app uses simple keyword rules."
        }
    }
}
