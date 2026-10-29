import Foundation
import Observation
import SwiftData

/// Shared app state: the store, screenshot sources, the AI provider and ingest.
@MainActor
@Observable
final class AppServices {
    let container: ModelContainer
    let progress: IngestProgress
    let boost: BoostSettings
    let skins: SkinStore
    private(set) var providerID = FallbackProvider.id
    /// Shown on Home when smart sorting isn't available.
    private(set) var providerNotice: String?

    @ObservationIgnored private let pipeline: IngestPipeline
    @ObservationIgnored private var provider: any AIProvider = FallbackProvider()
    @ObservationIgnored private var prepared = false
    @ObservationIgnored private var libraryWatcher: PhotoLibraryWatcher?
    @ObservationIgnored let photoSource = PhotoLibrarySource()
    @ObservationIgnored let sampleSource = SampleSource()

    /// True while the app is only hosting unit tests; it then skips its startup work so tests run in isolation.
    static let isHostingTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

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
        // Previews get their own settings so they never touch real keys.
        boost = inMemory
            ? BoostSettings(keychain: KeychainStore(service: "com.rokpremuz.ScreenshotSorter.preview"), defaults: UserDefaults(suiteName: "preview") ?? .standard)
            : BoostSettings()
        skins = SkinStore(defaults: inMemory ? (UserDefaults(suiteName: "preview") ?? .standard) : .standard)
        #if DEBUG
        skins.unlocksAllSkins = true
        #endif
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
        pipeline.start(sources: sources, provider: currentProvider())
    }

    /// Sorts any new screenshots now and waits. Returns how many were found. Used by pull-to-refresh.
    @discardableResult
    func refreshNow() async -> Int {
        prepare()
        return await pipeline.runAndWait(sources: sources, provider: currentProvider())
    }

    /// The background check iOS runs now and then: sort new screenshots, then notify if there were any.
    func backgroundCheck() async {
        guard UserDefaults.standard.bool(forKey: "hasOnboarded"), PhotoAccess.canRead else { return }
        let found = await refreshNow()
        let alertsOn = UserDefaults.standard.object(forKey: NewScreenshots.alertsKey) as? Bool ?? true
        guard NewScreenshots.shouldNotify(access: PhotoAccess.status, alertsOn: alertsOn, newCount: found),
              await NewScreenshots.notificationsAllowed() else { return }
        await NewScreenshots.postNotification(newCount: found)
    }

    /// Picks up new screenshots while the app is open.
    func watchLibrary() {
        guard libraryWatcher == nil, PhotoAccess.canRead else { return }
        libraryWatcher = PhotoLibraryWatcher { [weak self] in self?.startIngest() }
    }

    /// On-device sorting, wrapped with Boost when a cloud model is set up and switched on.
    private func currentProvider() -> any AIProvider {
        guard let cloud = boost.makeCloudProvider() else { return provider }
        return BoostRouter(local: provider, cloud: cloud, onCloudError: reportCloudError)
    }

    private var reportCloudError: @Sendable (String) async -> Void {
        { [boost] message in await boost.recordError(message) }
    }

    /// Sends items already sorted with low confidence to the cloud model. Returns how many improved.
    func improveUnsureItems() async -> Int {
        prepare()
        guard let cloud = boost.makeCloudProvider() else { return 0 }
        return await pipeline.improveUnsure(with: cloud, onError: reportCloudError)
    }

    /// How many items the phone wasn't sure about and the cloud hasn't seen yet.
    func unsureItemCount() -> Int {
        let threshold = BoostRouter.confidenceThreshold
        let deletedRaw = ItemStatus.deleted.rawValue
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.confidence < threshold && $0.statusRaw != deletedRaw })
        return ((try? container.mainContext.fetch(descriptor)) ?? []).filter { !$0.processedInCloud }.count
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
