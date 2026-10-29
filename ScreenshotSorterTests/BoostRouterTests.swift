import CoreGraphics
import Foundation
import Testing
@testable import ScreenshotSorter

/// A provider that returns a fixed result or error, and counts calls.
private struct FakeProvider: AIProvider {
    let id: String
    var result: Extraction?
    var error: CloudError?
    let calls = CallCounter()

    var isAvailable: Bool { get async { true } }

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        await calls.record(sawImage: image != nil)
        if let error { throw error }
        return result!
    }
}

private actor CallCounter {
    private(set) var count = 0
    private(set) var sawImage = false
    func record(sawImage image: Bool) {
        count += 1
        if image { sawImage = true }
    }
}

private actor ErrorLog {
    private(set) var messages: [String] = []
    func add(_ message: String) { messages.append(message) }
}

private func extraction(_ category: ItemCategory, confidence: Double, title: String = "Title") -> Extraction {
    Extraction(category: category, title: title, summary: "", fields: [:], url: nil, confidence: confidence)
}

struct BoostRouterTests {
    @Test func confidentItemsStayOnDevice() async throws {
        let local = FakeProvider(id: "apple-on-device", result: extraction(.jobs, confidence: 0.9))
        let cloud = FakeProvider(id: "claude", result: extraction(.posts, confidence: 0.9))
        let router = BoostRouter(local: local, cloud: cloud)

        let result = try await router.extract(text: "Senior designer", image: nil)
        #expect(result.category == .jobs)
        #expect(result.source == "apple-on-device")
        #expect(await cloud.calls.count == 0)
    }

    @Test func unsureItemsGoToTheCloudAsTextOnly() async throws {
        let local = FakeProvider(id: "fallback", result: extraction(.other, confidence: 0.2))
        let cloud = FakeProvider(id: "gemini", result: extraction(.jobs, confidence: 0.95, title: "Product Designer"))
        let router = BoostRouter(local: local, cloud: cloud)
        let image = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!.makeImage()

        let result = try await router.extract(text: "I'm hiring a Product Designer", image: image)
        #expect(result.category == .jobs)
        #expect(result.title == "Product Designer")
        #expect(result.source == "gemini")
        #expect(await cloud.calls.count == 1)
        #expect(await cloud.calls.sawImage == false)
    }

    @Test func cloudFailureFallsBackSilentlyAndReports() async throws {
        let local = FakeProvider(id: "fallback", result: extraction(.other, confidence: 0.2))
        let cloud = FakeProvider(id: "openai", error: .rateLimited("OpenAI"))
        let log = ErrorLog()
        let router = BoostRouter(local: local, cloud: cloud, onCloudError: { await log.add($0) })

        let result = try await router.extract(text: "Some text", image: nil)
        #expect(result.category == .other)
        #expect(result.source == "fallback")
        #expect(await log.messages.count == 1)
    }

    @Test func badKeyStopsCloudCallsForTheRun() async throws {
        let local = FakeProvider(id: "fallback", result: extraction(.other, confidence: 0.2))
        let cloud = FakeProvider(id: "claude", error: .unauthorized("Claude"))
        let router = BoostRouter(local: local, cloud: cloud)

        _ = try await router.extract(text: "One", image: nil)
        _ = try await router.extract(text: "Two", image: nil)
        _ = try await router.extract(text: "Three", image: nil)
        #expect(await cloud.calls.count == 1)
    }

    @Test func emptyTextIsNeverSent() async throws {
        let local = FakeProvider(id: "fallback", result: extraction(.other, confidence: 0.2))
        let cloud = FakeProvider(id: "claude", result: extraction(.jobs, confidence: 0.9))
        let router = BoostRouter(local: local, cloud: cloud)

        _ = try await router.extract(text: "   \n", image: nil)
        #expect(await cloud.calls.count == 0)
    }

    @Test func localFailureStillGetsBoosted() async throws {
        let local = FakeProvider(id: "apple-on-device", error: .badReply("Apple"))
        let cloud = FakeProvider(id: "claude", result: extraction(.receipts, confidence: 0.9))
        let router = BoostRouter(local: local, cloud: cloud)

        let result = try await router.extract(text: "Receipt Total €19.40", image: nil)
        #expect(result.category == .receipts)
        #expect(result.source == "claude")
    }

    @Test func routerIDIsBoostOnlyWithACloudModel() {
        let local = FakeProvider(id: "fallback", result: extraction(.other, confidence: 0.2))
        #expect(BoostRouter(local: local, cloud: nil).id == "fallback")
        #expect(BoostRouter(local: local, cloud: FakeProvider(id: "claude")).id == "boost")
    }
}
