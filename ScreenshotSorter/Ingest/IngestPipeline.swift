import CoreGraphics
import Foundation
import OSLog
import SwiftData

/// Starts processing and reports progress. Only one run at a time.
@MainActor
final class IngestPipeline {
    private let worker: IngestWorker
    private let progress: IngestProgress
    private var task: Task<Void, Never>?
    /// How many new screenshots the latest run found.
    private(set) var lastFoundCount = 0

    init(container: ModelContainer, progress: IngestProgress) {
        self.worker = IngestWorker(modelContainer: container)
        self.progress = progress
    }

    /// Processes every screenshot not yet in the store, newest first.
    func start(sources: [any ScreenshotSource], provider: any AIProvider) {
        guard task == nil else { return }
        let worker = worker
        let progress = progress
        task = Task {
            defer { self.task = nil }
            var assets: [SourceAsset] = []
            for source in sources { assets += await source.assets() }
            assets.sort { $0.createdAt > $1.createdAt }
            let pending = await worker.pending(assets)
            self.lastFoundCount = pending.count
            guard !pending.isEmpty else { return }
            progress.begin(total: pending.count)
            let modelGaveUp = await worker.process(pending, sources: sources, provider: provider) { done in
                await progress.update(done: done)
            }
            if modelGaveUp { progress.markModelFailed() }
            progress.finish()
        }
    }

    /// Runs (or joins) a sort and waits for it. Returns how many new screenshots it found.
    func runAndWait(sources: [any ScreenshotSource], provider: any AIProvider) async -> Int {
        start(sources: sources, provider: provider)
        await task?.value
        return lastFoundCount
    }

    /// Sends unsure items already in the store to the cloud. Waits for any running sort to finish first.
    func improveUnsure(with cloud: any AIProvider, onError: @escaping @Sendable (String) async -> Void) async -> Int {
        await task?.value
        return await worker.improveUnsure(with: cloud, onError: onError)
    }

    /// Stops the current run and waits for it to finish.
    func cancel() async {
        task?.cancel()
        await task?.value
        task = nil
        progress.finish()
    }
}

/// Does the heavy work off the main actor, with its own model context.
@ModelActor
actor IngestWorker {
    private static let logger = Logger(subsystem: "com.rokpremuz.ScreenshotSorter", category: "Ingest")
    /// Saves after this many items early on so the first cards show up fast, then every batch.
    private static let firstSaveAt = 5
    private static let batchSize = 20
    /// OCR resolution. Screenshots are about 1179–1320 px wide.
    private static let ocrWidth: CGFloat = 1_200
    /// Below this much text, the image goes to the model too.
    private static let attachImageBelowCharacters = 40
    /// After this many model failures in a row, the rest of the run uses keyword rules.
    private static let maxConsecutiveFailures = 3

    private var consecutiveFailures = 0
    private var modelDisabled = false

    func pending(_ assets: [SourceAsset]) -> [SourceAsset] {
        let known = (try? ItemStore.knownAssetIDs(in: modelContext)) ?? []
        return assets.filter { !known.contains($0.id) }
    }

    func process(
        _ assets: [SourceAsset],
        sources: [any ScreenshotSource],
        provider: any AIProvider,
        onProgress: @escaping @Sendable (Int) async -> Void
    ) async -> Bool {
        consecutiveFailures = 0
        modelDisabled = false
        let recognizer = TextRecognizer()
        for (index, asset) in assets.enumerated() {
            if Task.isCancelled { break }
            if let source = sources.first(where: { $0.owns(asset.id) }) {
                await processOne(asset, source: source, provider: provider, recognizer: recognizer)
            }
            let done = index + 1
            if done == Self.firstSaveAt || done % Self.batchSize == 0 || done == assets.count {
                try? modelContext.save()
                await onProgress(done)
            }
        }
        try? modelContext.save()
        return modelDisabled
    }

    private func processOne(_ asset: SourceAsset, source: any ScreenshotSource, provider: any AIProvider, recognizer: TextRecognizer) async {
        // A missing image (deleted, or iCloud failed) is skipped and retried on the next launch.
        guard let image = await source.image(for: asset.id, maxWidth: Self.ocrWidth) else { return }
        let text = (try? await recognizer.text(in: image)) ?? ""
        let capture = Capture(
            assetID: asset.id,
            createdAt: asset.createdAt,
            ocrText: text,
            imageHash: ImageHasher.hash(image),
            fileSize: await source.fileSize(for: asset.id)
        )

        if (try? ItemStore.attachIfDuplicate(capture, in: modelContext)) != nil {
            try? modelContext.save()
            return
        }

        let imageForModel = text.count < Self.attachImageBelowCharacters ? image : nil
        var extraction = FallbackProvider.classify(text)
        var providerID = FallbackProvider.id
        if !modelDisabled && provider.id != FallbackProvider.id {
            do {
                extraction = try await provider.extract(text: text, image: imageForModel)
                // Boost may hand an item to the cloud; record who actually sorted it.
                providerID = extraction.source ?? provider.id
                consecutiveFailures = 0
            } catch {
                // Logs the error only, never screenshot text.
                Self.logger.error("\(provider.id, privacy: .public) failed, using keyword rules: \(String(describing: error), privacy: .public)")
                consecutiveFailures += 1
                if consecutiveFailures >= Self.maxConsecutiveFailures {
                    modelDisabled = true
                    Self.logger.error("\(provider.id, privacy: .public) failed \(Self.maxConsecutiveFailures) times in a row; keyword rules for the rest of this run")
                }
            }
        }
        ItemStore.insert(capture, extraction: extraction, providerID: providerID, in: modelContext)
        // Saving each item keeps duplicate checks accurate and lets Home fill in as items arrive.
        try? modelContext.save()
    }

    /// Re-sorts items the phone was unsure about with a cloud model, using the stored OCR text only.
    /// Returns how many items were improved.
    func improveUnsure(with cloud: any AIProvider, onError: @escaping @Sendable (String) async -> Void) async -> Int {
        let threshold = BoostRouter.confidenceThreshold
        let deletedRaw = ItemStatus.deleted.rawValue
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.confidence < threshold && $0.statusRaw != deletedRaw })
        let unsure = ((try? modelContext.fetch(descriptor)) ?? []).filter { !$0.processedInCloud }
        let breaker = CloudBreaker()
        var improved = 0
        for item in unsure {
            let allowed = await breaker.allows()
            if Task.isCancelled || !allowed { break }
            let text = item.sortedScreenshots.map(\.ocrText).joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            do {
                let result = try await cloud.extract(text: text, image: nil)
                item.category = result.category
                item.title = result.title
                item.summary = result.summary
                item.fields = result.fields
                item.url = result.url
                item.confidence = result.confidence
                item.processedBy = cloud.id
                try? modelContext.save()
                await breaker.recordSuccess()
                improved += 1
            } catch {
                await breaker.recordFailure(permanent: (error as? CloudError)?.isPermanent ?? false)
                await onError(error.localizedDescription)
            }
        }
        return improved
    }
}
