import Foundation
import Observation
import SwiftData

/// Shared app state: the store, screenshot sources, the AI provider and ingest.
@MainActor
@Observable
final class AppServices {
    let container: ModelContainer
    let progress: IngestProgress
    private(set) var providerID = FallbackProvider.id
    /// Shown on Home when smart sorting isn't available.
    private(set) var providerNotice: String?

    @ObservationIgnored private let pipeline: IngestPipeline
    @ObservationIgnored private var provider: any AIProvider = FallbackProvider()
    @ObservationIgnored private var prepared = false
    @ObservationIgnored let photoSource = PhotoLibrarySource()
    @ObservationIgnored let sampleSource = SampleSource()

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: Item.self, Screenshot.self, Stats.self, configurations: configuration)
        } catch {
            fatalError("Couldn't open the store: \(error)")
        }
        let progress = IngestProgress()
        self.progress = progress
        pipeline = IngestPipeline(container: container, progress: progress)
    }

    var sources: [any ScreenshotSource] {
        #if DEBUG
        [photoSource, sampleSource]
        #else
        [photoSource]
        #endif
    }

    func source(for assetID: String) -> any ScreenshotSource {
        sampleSource.owns(assetID) ? sampleSource : photoSource
    }

    var deleter: any AssetDeleting { DeleteCommitter(sources: sources) }

    /// Picks the provider and cleans up any triage session that was cut short.
    func prepare() {
        guard !prepared else { return }
        prepared = true
        let resolution = ProviderResolver.resolve()
        provider = resolution.provider
        providerID = resolution.provider.id
        providerNotice = resolution.notice
        ItemStore.resetInterruptedDeletes(in: container.mainContext)
    }

    func startIngest() {
        prepare()
        pipeline.start(sources: sources, provider: provider)
    }

    func reprocessAll() async {
        await pipeline.cancel()
        ItemStore.wipeItems(in: container.mainContext)
        startIngest()
    }

    func wipeStore() async {
        await pipeline.cancel()
        ItemStore.wipeAll(in: container.mainContext)
    }

    /// In-memory services with sample items, for previews.
    static let preview: AppServices = {
        let services = AppServices(inMemory: true)
        SampleData.insert(into: services.container.mainContext)
        return services
    }()
}
