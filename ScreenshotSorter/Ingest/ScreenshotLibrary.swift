import Photos
import UIKit

enum PhotoAccess {
    static var status: PHAuthorizationStatus { PHPhotoLibrary.authorizationStatus(for: .readWrite) }
    static var canRead: Bool { status == .authorized || status == .limited }

    static func request() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
}

/// Adds up chunk sizes from Photos callbacks, which may arrive on any thread.
private final class ByteCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = 0
    func add(_ count: Int) { lock.withLock { bytes += count } }
    var total: Int { lock.withLock { bytes } }
}

/// Screenshots from the Photos library. Only the screenshot media subtype is ever fetched.
struct PhotoLibrarySource: ScreenshotSource {
    func owns(_ id: String) -> Bool { !id.hasPrefix(SampleSource.prefix) }

    func assets() async -> [SourceAsset] {
        guard PhotoAccess.canRead else { return [] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [SourceAsset] = []
        assets.reserveCapacity(result.count)
        for index in 0..<result.count {
            let asset = result.object(at: index)
            assets.append(SourceAsset(id: asset.localIdentifier, createdAt: asset.creationDate ?? .distantPast))
        }
        return assets
    }

    func image(for id: String, maxWidth: CGFloat) async -> CGImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
              asset.pixelWidth > 0 else { return nil }
        // Scale by width so long scrolling screenshots stay readable for OCR.
        let scale = min(1, maxWidth / CGFloat(asset.pixelWidth))
        let size = CGSize(width: CGFloat(asset.pixelWidth) * scale, height: CGFloat(asset.pixelHeight) * scale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { image, _ in
                // With .highQualityFormat the handler is called exactly once.
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    /// Measures the original file with public API only. Nothing is downloaded: a screenshot that's
    /// only in iCloud gets an estimate from its pixel size instead.
    func fileSize(for id: String) async -> Int {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return 0 }
        let estimate = asset.pixelWidth * asset.pixelHeight / 2
        let resources = PHAssetResource.assetResources(for: asset)
        guard let original = resources.first(where: { $0.type == .photo }) ?? resources.first else { return estimate }
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false
        let counter = ByteCounter()
        return await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().requestData(for: original, options: options) { chunk in
                counter.add(chunk.count)
            } completionHandler: { error in
                continuation.resume(returning: error == nil ? counter.total : estimate)
            }
        }
    }

    /// One request for all assets, so iOS shows a single confirmation.
    func delete(_ ids: [String]) async -> Bool {
        guard !ids.isEmpty else { return true }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                PHAssetChangeRequest.deleteAssets(assets)
            }
            return true
        } catch {
            return false
        }
    }
}
