import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \Item.savedAt, order: .reverse) private var items: [Item]
    @State private var triage: TriageTarget?
    @State private var showDebug = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

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

                if items.isEmpty {
                    emptyState
                } else {
                    backlogHeader(unreviewed: unreviewed)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ItemCategory.allCases.filter { groups[$0] != nil }) { category in
                            let categoryItems = groups[category] ?? []
                            NavigationLink(value: category) {
                                CategoryCard(
                                    category: category,
                                    itemCount: categoryItems.count,
                                    unreviewedCount: categoryItems.filter { $0.status == .new }.count
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                BottomBar {
                    WideButton(title: "Start triage", systemImage: "rectangle.stack") {
                        triage = TriageTarget(category: nil)
                    }
                    .disabled(unreviewed == 0)
                }
            }
        }
        .navigationTitle("Screenshots")
        .navigationDestination(for: ItemCategory.self) { CategoryListView(category: $0) }
        .navigationDestination(for: Item.self) { ItemDetailView(item: $0) }
        .fullScreenCover(item: $triage) { TriageView(category: $0.category) }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Debug", systemImage: "ladybug") { showDebug = true }
            }
        }
        .sheet(isPresented: $showDebug) { DebugMenuView() }
        #endif
    }

    private func backlogHeader(unreviewed: Int) -> some View {
        let fraction = items.isEmpty ? 0 : Double(items.count - unreviewed) / Double(items.count)
        return HStack(spacing: 16) {
                ProgressRing(fraction: fraction)
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(unreviewed == 0 ? "All sorted" : "\(unreviewed) to review")
                        .font(.title3.bold())
                    Text(items.count == 1 ? "1 item from your screenshots" : "\(items.count) items from your screenshots")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
        }
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
