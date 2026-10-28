import CoreGraphics
import Foundation
import ImageIO

/// Debug samples imported from Files into the app's own folder.
/// Images added to the Simulator's Photos aren't marked as screenshots, so this is how to test there.
struct SampleSource: ScreenshotSource {
    static let prefix = "sample:"

    static var folder: URL {
        URL.documentsDirectory.appending(path: "Samples", directoryHint: .isDirectory)
    }

    func owns(_ id: String) -> Bool { id.hasPrefix(Self.prefix) }

    private func fileURL(for id: String) -> URL {
        Self.folder.appending(path: String(id.dropFirst(Self.prefix.count)))
    }

    func assets() async -> [SourceAsset] {
        let keys: [URLResourceKey] = [.creationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: keys) else { return [] }
        return files
            .map { url in
                let created = (try? url.resourceValues(forKeys: Set(keys)).creationDate) ?? .distantPast
                return SourceAsset(id: Self.prefix + url.lastPathComponent, createdAt: created)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func image(for id: String, maxWidth: CGFloat) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL(for: id) as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0 else { return nil }
        // Thumbnail size is set on the longest side, so convert the width limit.
        let longest = max(width, height) * min(1, maxWidth / width)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longest,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    func fileSize(for id: String) async -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL(for: id).path(percentEncoded: false))
        return (attributes?[.size] as? Int) ?? 0
    }

    func delete(_ ids: [String]) async -> Bool {
        for id in ids { try? FileManager.default.removeItem(at: fileURL(for: id)) }
        return true
    }

    /// Copies picked files into the samples folder. Returns how many were added.
    static func importFiles(_ urls: [URL]) throws -> Int {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var added = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let destination = folder.appending(path: UUID().uuidString + "-" + url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: destination)
            added += 1
        }
        return added
    }
}
