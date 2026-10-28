import SwiftData
import SwiftUI

struct ItemDetailView: View {
    let item: Item

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewer: ScreenshotViewer.Target?
    @State private var isDeleting = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(item.category.name, systemImage: item.category.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(item.title)
                        .font(.title2.bold())
                    if !item.summary.isEmpty {
                        Text(item.summary)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if item.category.fieldKeys.contains(where: { item.displayValue(for: $0) != nil }) {
                Section("Details") {
                    FieldRows(item: item)
                }
            }

            if let link = item.link {
                Section {
                    Link(destination: link) {
                        Label("Open link", systemImage: "safari")
                    }
                }
            }

            Section("Screenshots") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        let screenshots = item.sortedScreenshots
                        ForEach(Array(screenshots.enumerated()), id: \.offset) { index, screenshot in
                            Button {
                                viewer = .init(assetIDs: screenshots.map(\.assetID), start: index)
                            } label: {
                                ThumbnailView(assetID: screenshot.assetID, maxWidth: 300)
                                    .frame(width: 90, height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Screenshot \(index + 1)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Label(processedLabel, systemImage: item.processedInCloud ? "cloud" : "iphone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(item.category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Keep", systemImage: "checkmark") {
                    ItemStore.markKept(item, in: context)
                }
                .disabled(item.status == .kept)

                Spacer()

                Menu {
                    ForEach(ItemCategory.allCases) { category in
                        Button(category.name, systemImage: category.symbol) {
                            item.category = category
                            try? context.save()
                        }
                        .disabled(category == item.category)
                    }
                } label: {
                    Label("Move", systemImage: "folder")
                }

                Spacer()

                Button("Delete", systemImage: "trash", role: .destructive) {
                    Task { await delete() }
                }
                .disabled(isDeleting)
            }
        }
        .fullScreenCover(item: $viewer) { ScreenshotViewer(target: $0) }
    }

    private var processedLabel: String {
        if item.processedInCloud { return "Processed in the cloud" }
        if item.processedBy == FallbackProvider.id { return "Processed on this iPhone with basic keyword sorting" }
        return "Processed on this iPhone"
    }

    private func delete() async {
        isDeleting = true
        let deleted = await DeleteCommitter.deleteItem(item, deleter: services.deleter, context: context)
        isDeleting = false
        if deleted { dismiss() }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: SampleData.firstItem(in: AppServices.preview.container.mainContext))
    }
    .environment(AppServices.preview)
    .modelContainer(AppServices.preview.container)
}
