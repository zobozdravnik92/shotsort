import CoreGraphics
import Foundation

/// A 256-bit difference hash (dHash). Identical screens give the same hash.
/// Screens that share a layout can collide too, so duplicates also need matching text (see `ItemStore`).
enum ImageHasher {
    private static let width = 17
    private static let height = 16

    static func hash(_ image: CGImage) -> String {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return "" }

        var hex = ""
        var nibble: UInt8 = 0
        var bitCount = 0
        for row in 0..<height {
            for column in 0..<(width - 1) {
                let left = pixels[row * width + column]
                let right = pixels[row * width + column + 1]
                nibble = (nibble << 1) | (left > right ? 1 : 0)
                bitCount += 1
                if bitCount == 4 {
                    hex += String(nibble, radix: 16)
                    nibble = 0
                    bitCount = 0
                }
            }
        }
        return hex
    }
}
