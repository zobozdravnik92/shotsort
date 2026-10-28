import CoreGraphics
import Foundation

struct SourceAsset: Sendable, Equatable {
    let id: String
    let createdAt: Date
}

/// Where screenshots come from: the Photos library, or debug samples imported from Files.
protocol ScreenshotSource: Sendable {
    /// Newest first.
    func assets() async -> [SourceAsset]
    /// The image scaled down to at most `maxWidth` pixels wide.
    func image(for id: String, maxWidth: CGFloat) async -> CGImage?
    func fileSize(for id: String) async -> Int
    func owns(_ id: String) -> Bool
    /// Returns false if the user cancels or deleting fails.
    func delete(_ ids: [String]) async -> Bool
}
