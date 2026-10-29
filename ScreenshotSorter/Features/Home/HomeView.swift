import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \Item.savedAt, order: .reverse) private var items: [Item]
    @State private var triage: TriageTarget?
    @State private var showDebug = false
    @State private var showSettings = false
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var photoAccess = PhotoAccess.status
    @State private var isRefreshing = false
    @AppStorage("userName") private var userName = "Rok"
    private let router = NotificationRouter.shared

    var body: some View {
        let unreviewed = items.filter { $0.status == .new }.count
        let groups = Dictionary(grouping: items.filter { $0.status != .deleted }, by: \.category)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let notice = services.providerNotice {
                    NoticeBanner(systemImage: "info.circle", text: notice)
                } else if services.progress.modelFailed {
                    NoticeBanner(systemImage: "exclamationmark.triangle", text: "Smart sorting kept failing on this iPhone, so some screenshots were sorted with simple keyword rules.")
                }
                if services.progress.isRunning {
                    ProcessingBanner(progress: services.progress)
                }
                if photoAccess == .limited {
                    LimitedAccessBanner {
                        Task {
                            await PhotoAccess.presentLimitedPicker()
                            await refresh()
                        }
                    }
                }

                if items.isEmpty {
                    emptyState
                } else {
                    backlogHeader(unreviewed: unreviewed)
                    CategoryMosaic(summaries: groups.map { category, list in
                        CategorySummary(
                            category: category,
                            itemCount: list.count,
                            screenshotCount: list.reduce(0) { $0 + $1.screenshots.count },
                            unreviewedCount: list.filter { $0.status == .new }.count
                        )
                    })
                }
            }
            .padding()
        }
        // Pull down to look for new screenshots, whatever the Photos access.
        .refreshable { await refresh() }
        .background { ThemedBackground() }
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                BottomBar(fade: theme.background) {
                    WideButton(title: "Start triage", systemImage: "rectangle.stack") {
                        triage = TriageTarget(category: nil)
                    }
                    .disabled(unreviewed == 0)
                }
            }
        }
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The big header below replaces the system title.
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
        }
        .navigationDestination(for: ItemCategory.self) { CategoryListView(category: $0) }
        .navigationDestination(for: Item.self) { ItemDetailView(item: $0) }
        .fullScreenCover(item: $triage) { TriageView(category: $0.category) }
        .toolbar {
            // Greeting, level with the Settings and Debug buttons. The name is a placeholder until accounts exist.
            ToolbarItem(placement: .topBarLeading) {
                Text(theme.text("Hi \(userName)"))
                    .font(theme.fontName != nil ? theme.font(20) : .system(size: 20, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.ink)
                    .fixedSize()
                    .accessibilityAddTraits(.isHeader)
            }
            .sharedBackgroundVisibility(.hidden)
            // Without full access the app can't check by itself, so offer a refresh button.
            if photoAccess != .authorized {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await refresh() }
                    }
                    .disabled(isRefreshing)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") { showSettings = true }
            }
            .sharedBackgroundVisibility(.hidden)
            #if DEBUG
            ToolbarItem(placement: .topBarTrailing) {
                Button("Debug", systemImage: "ladybug") { showDebug = true }
            }
            .sharedBackgroundVisibility(.hidden)
            #endif
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        // A tapped "new screenshots" notification opens triage.
        .onChange(of: router.triageRequest) { _, request in openTriageIfRequested(request) }
        .onAppear { openTriageIfRequested(router.triageRequest) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { photoAccess = PhotoAccess.status }
        }
        #if DEBUG
        .sheet(isPresented: $showDebug) { DebugMenuView() }
        #endif
    }

    private func refresh() async {
        isRefreshing = true
        photoAccess = PhotoAccess.status
        await services.refreshNow()
        isRefreshing = false
    }

    private func openTriageIfRequested(_ request: UUID?) {
        guard request != nil else { return }
        router.consume()
        showSettings = false
        showDebug = false
        if triage == nil { triage = TriageTarget(category: nil) }
    }

    private func backlogHeader(unreviewed: Int) -> some View {
        ScreenHeader(
            title: unreviewed == 0 ? "All sorted" : "\(unreviewed) to review",
            subtitle: items.count == 1 ? "of 1 item" : "of \(items.count) items"
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        if services.progress.isRunning {
            ContentUnavailableView(
                "Sorting your screenshots",
                systemImage: "sparkles",
                description: Text("The first groups will appear in a moment.")
            )
        } else {
            ContentUnavailableView(
                "No screenshots yet",
                systemImage: "camera.viewfinder",
                description: Text("Take a screenshot and open the app again. If you shared only some photos, you can change that in Settings.")
            )
        }
    }
}

private struct ProcessingBanner: View {
    let progress: IngestProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sorting screenshots… \(progress.done) of \(progress.total)")
                .font(.subheadline)
            ProgressView(value: progress.fraction)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppServices.preview)
    .modelContainer(AppServices.preview.container)
}

/// Limited Photos access: new screenshots only appear once the user shares them.
private struct LimitedAccessBanner: View {
    let onAddScreenshots: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        ThemedPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("You've shared only some photos, so new screenshots won't appear by themselves. Share them, or pull down to refresh.")
                    .font(.system(.subheadline, design: theme.fontDesign))
                Button(action: onAddScreenshots) {
                    Label(theme.text("Add screenshots"), systemImage: "plus.circle")
                        .font(.system(.subheadline, design: theme.fontDesign).weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
