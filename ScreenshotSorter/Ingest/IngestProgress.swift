import Observation

/// First-run and later processing progress, shown on Home.
@MainActor
@Observable
final class IngestProgress {
    private(set) var total = 0
    private(set) var done = 0
    private(set) var isRunning = false
    /// True when the AI model kept failing during the last run and keyword rules took over.
    private(set) var modelFailed = false

    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    func begin(total: Int) {
        self.total = total
        done = 0
        isRunning = true
    }

    func markModelFailed() {
        modelFailed = true
    }

    func update(done: Int) {
        self.done = done
    }

    func finish() {
        isRunning = false
    }
}
