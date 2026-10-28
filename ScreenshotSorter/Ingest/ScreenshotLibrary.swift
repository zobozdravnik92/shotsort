import Photos
import UIKit

enum PhotoAccess {
    static var status: PHAuthorizationStatus { PHPhotoLibrary.authorizationStatus(for: .readWrite) }
    static var canRead: Bool { status == .authorized || status == .limited }

    static func request() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
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

    func fileSize(for id: String) async -> Int {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return 0 }
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.lazy.compactMap { $0.value(forKey: "fileSize") as? Int }.first ?? 0
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
