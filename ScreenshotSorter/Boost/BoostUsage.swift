import CoreGraphics
import Foundation

/// How many screenshots Boost has sorted, per calendar month. Counts only; no screenshot text.
struct BoostUsage: Codable, Equatable, Sendable {
    /// Successful cloud sorts, keyed by month ("2026-11").
    var boosted: [String: Int] = [:]
    /// Cloud calls that failed (the phone's own result was kept), keyed by month.
    var failed: [String: Int] = [:]

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    mutating func recordSuccess(at date: Date = .now, calendar: Calendar = .current) {
        boosted[Self.monthKey(for: date, calendar: calendar), default: 0] += 1
    }

    mutating func recordFailure(at date: Date = .now, calendar: Calendar = .current) {
        failed[Self.monthKey(for: date, calendar: calendar), default: 0] += 1
    }

    func boosted(inMonthOf date: Date, calendar: Calendar = .current) -> Int {
        boosted[Self.monthKey(for: date, calendar: calendar)] ?? 0
    }

    func failed(inMonthOf date: Date, calendar: Calendar = .current) -> Int {
        failed[Self.monthKey(for: date, calendar: calendar)] ?? 0
    }

    func boostedLastMonth(from date: Date = .now, calendar: Calendar = .current) -> Int {
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: date) else { return 0 }
        return boosted(inMonthOf: lastMonth, calendar: calendar)
    }

    var boostedAllTime: Int { boosted.values.reduce(0, +) }
}

/// Wraps a cloud model and reports each call's outcome, so Boost usage can be counted.
/// Keeps the wrapped model's `id`, which is stored on items as `processedBy`.
struct CountingProvider: AIProvider {
    let inner: any AIProvider
    let onResult: @Sendable (_ succeeded: Bool) async -> Void

    var id: String { inner.id }
    var isAvailable: Bool { get async { await inner.isAvailable } }

    func extract(text: String, image: CGImage?) async throws -> Extraction {
        do {
            let result = try await inner.extract(text: text, image: image)
            await onResult(true)
            return result
        } catch {
            await onResult(false)
            throw error
        }
    }
}
