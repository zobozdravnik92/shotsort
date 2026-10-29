import CoreGraphics
import Foundation

/// On-device first. Only screenshots the phone is unsure about go to the cloud, as text only.
/// Any cloud failure quietly falls back to the on-device result (spec §12, Phase 4).
struct BoostRouter: AIProvider {
    static let confidenceThreshold = 0.5

    let local: any AIProvider
    let cloud: (any AIProvider)?
    let breaker: CloudBreaker
    /// Reports a failure to Settings. Never includes screenshot text.
    let onCloudError: @Sendable (String) async -> Void

    init(local: any AIProvider, cloud: (any AIProvider)?, breaker: CloudBreaker = CloudBreaker(), onCloudError: @escaping @Sendable (String) async -> Void = { _ in }) {
        self.local = local
        self.cloud = cloud
        self.breaker = breaker
        self.onCloudError = onCloudError
    }

    /// "boost" while a cloud model is set up, so the ingest worker always calls the router.
    var id: String { cloud == nil ? local.id : "boost" }
    var isAvailable: Bool { get async { await local.isAvailable } }

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        var onDevice: Extraction
        do {
            onDevice = try await local.extract(text: text, image: image)
            onDevice.source = onDevice.source ?? local.id
        } catch {
            guard cloud != nil else { throw error }
            onDevice = FallbackProvider.classify(text)
            onDevice.source = FallbackProvider.id
        }

        guard let cloud,
              onDevice.confidence < Self.confidenceThreshold,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              await breaker.allows() else { return onDevice }

        do {
            // Text only: images never leave the phone.
            var boosted = try await cloud.extract(text: text, image: nil)
            boosted.source = cloud.id
            await breaker.recordSuccess()
            return boosted
        } catch {
            let permanent = (error as? CloudError)?.isPermanent ?? false
            await breaker.recordFailure(permanent: permanent)
            await onCloudError(error.localizedDescription)
            return onDevice
        }
    }
}

/// Stops calling the cloud for the rest of a run after a permanent error (bad key) or repeated failures.
actor CloudBreaker {
    private let maxFailures: Int
    private var failures = 0
    private var tripped = false

    init(maxFailures: Int = 3) {
        self.maxFailures = maxFailures
    }

    func allows() -> Bool { !tripped }

    func recordSuccess() { failures = 0 }

    func recordFailure(permanent: Bool) {
        failures += 1
        if permanent || failures >= maxFailures { tripped = true }
    }
}
