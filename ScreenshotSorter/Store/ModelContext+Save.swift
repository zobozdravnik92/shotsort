import OSLog
import SwiftData

extension ModelContext {
    private static let logger = Logger(subsystem: "com.rokpremuz.ScreenshotSorter", category: "Store")

    /// Saves, and logs a failure instead of hiding it. Logs the error type only, never item content.
    func saveOrLog(_ file: StaticString = #fileID, line: UInt = #line) {
        do {
            try save()
        } catch {
            Self.logger.error("Save failed at \(file, privacy: .public):\(line): \(String(reflecting: type(of: error)), privacy: .public)")
        }
    }
}
