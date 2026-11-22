import CoreGraphics
import Foundation
import Testing
@testable import ScreenshotSorter

private struct StubProvider: AIProvider {
    let id = "claude"
    var fails = false
    var isAvailable: Bool { get async { true } }

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        if fails { throw CloudError.rateLimited("Claude") }
        return Extraction(category: .jobs, title: "T", summary: "", fields: [:], url: nil, confidence: 0.9)
    }
}

private actor Outcomes {
    private(set) var values: [Bool] = []
    func add(_ value: Bool) { values.append(value) }
}

struct BoostUsageTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func countsPerMonth() {
        var usage = BoostUsage()
        usage.recordSuccess(at: date(2026, 10, 30), calendar: calendar)
        usage.recordSuccess(at: date(2026, 11, 1), calendar: calendar)
        usage.recordSuccess(at: date(2026, 11, 19), calendar: calendar)
        usage.recordFailure(at: date(2026, 11, 19), calendar: calendar)

        #expect(usage.boosted(inMonthOf: date(2026, 11, 20), calendar: calendar) == 2)
        #expect(usage.boostedLastMonth(from: date(2026, 11, 20), calendar: calendar) == 1)
        #expect(usage.failed(inMonthOf: date(2026, 11, 20), calendar: calendar) == 1)
        #expect(usage.boostedAllTime == 3)
    }

    @Test func lastMonthCrossesTheYear() {
        var usage = BoostUsage()
        usage.recordSuccess(at: date(2025, 12, 31), calendar: calendar)
        #expect(usage.boostedLastMonth(from: date(2026, 1, 15), calendar: calendar) == 1)
        #expect(BoostUsage.monthKey(for: date(2026, 1, 15), calendar: calendar) == "2026-01")
    }

    @Test func survivesEncoding() throws {
        var usage = BoostUsage()
        usage.recordSuccess(at: date(2026, 11, 3), calendar: calendar)
        let decoded = try JSONDecoder().decode(BoostUsage.self, from: JSONEncoder().encode(usage))
        #expect(decoded == usage)
    }

    @Test func countingProviderReportsEachCallAndKeepsTheID() async throws {
        let outcomes = Outcomes()
        let ok = CountingProvider(inner: StubProvider()) { await outcomes.add($0) }
        let failing = CountingProvider(inner: StubProvider(fails: true)) { await outcomes.add($0) }

        #expect(ok.id == "claude")
        _ = try await ok.extract(text: "hello", image: nil)
        await #expect(throws: CloudError.self) { try await failing.extract(text: "hello", image: nil) }
        #expect(await outcomes.values == [true, false])
    }

    @MainActor
    @Test func settingsSaveUsage() {
        let suite = "boost-usage-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let keychain = KeychainStore(service: "com.rokpremuz.ScreenshotSorter.tests.\(UUID().uuidString)")

        let settings = BoostSettings(keychain: keychain, defaults: defaults)
        settings.recordUse(succeeded: true)
        settings.recordUse(succeeded: true)
        settings.recordUse(succeeded: false)

        let reloaded = BoostSettings(keychain: keychain, defaults: defaults)
        #expect(reloaded.usage.boosted(inMonthOf: .now) == 2)
        #expect(reloaded.usage.failed(inMonthOf: .now) == 1)
    }
}
