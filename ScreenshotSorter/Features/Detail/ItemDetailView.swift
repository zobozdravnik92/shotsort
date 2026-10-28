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
        }
        .navigationTitle(item.category.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                WideButton(title: deleteTitle, systemImage: "trash", tint: .red) {
                    Task { await delete() }
                }
                .disabled(isDeleting)
            }
        }
        .fullScreenCover(item: $viewer) { target in
            ScreenshotViewer(
                target: target,
                onDelete: { Task { await delete() } },
                deleteTitle: deleteTitle
            )
        }
    }

    private var deleteTitle: String {
        item.screenshots.count > 1 ? "Delete \(item.screenshots.count) screenshots" : "Delete screenshot"
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
