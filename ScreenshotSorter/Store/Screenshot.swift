import Foundation
import SwiftData

@Model
final class Screenshot {
    /// PHAsset local identifier, or "sample:<file>" for debug samples.
    @Attribute(.unique) var assetID: String
    var createdAt: Date
    var ocrText: String
    /// Perceptual hash used to spot exact duplicates.
    var imageHash: String
    /// Bytes, used for "space freed".
    var fileSize: Int
    var processedAt: Date?
    var item: Item?

    init(assetID: String, createdAt: Date, ocrText: String, imageHash: String, fileSize: Int, processedAt: Date? = nil) {
        self.assetID = assetID
        self.createdAt = createdAt
        self.ocrText = ocrText
        self.imageHash = imageHash
        self.fileSize = fileSize
        self.processedAt = processedAt
    }
}
