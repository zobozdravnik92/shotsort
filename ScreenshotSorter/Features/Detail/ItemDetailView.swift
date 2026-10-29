import SwiftData
import SwiftUI

struct ItemDetailView: View {
    let item: Item

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewer: ScreenshotViewer.Target?
    @State private var isDeleting = false
    @State private var expandedShots: Set<Int> = []
    /// Screen positions, measured once before any scrolling: the first screenshot's top and the Delete button's top.
    @State private var firstShotTop: CGFloat = 0
    @State private var barTop: CGFloat = 0

    /// Fills the screen from the screenshot's top down to just above the Delete button.
    private var firstShotHeight: CGFloat {
        guard barTop > 0, firstShotTop > 0, barTop > firstShotTop else { return 440 }
        return max(280, barTop - firstShotTop + 12)
    }
    @Environment(\.theme) private var theme

    private var fieldKeys: [String] {
        item.category.fieldKeys.filter { item.displayValue(for: $0) != nil }
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 12) {
                // Title and summary sit straight on the page, in the skin's ink.
                VStack(alignment: .leading, spacing: 10) {
                    Text(theme.text(item.title))
                        .font(theme.font(26))
                        .tracking(theme.tracking(26))
                        .lineSpacing(theme.wrapSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                    if !item.summary.isEmpty {
                        Text(item.summary)
                            .font(.system(.body, design: theme.fontDesign))
                            .opacity(0.75)
                    }
                }
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

                if !fieldKeys.isEmpty {
                    ThemedLabel(text: "Details").padding(.top, 8)
                    ThemedPanel {
                        VStack(spacing: 10) {
                            ForEach(fieldKeys, id: \.self) { key in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(theme.text(ItemCategory.fieldLabel(key))).opacity(0.6)
                                    Spacer(minLength: 12)
                                    Text(item.displayValue(for: key) ?? "").multilineTextAlignment(.trailing)
                                }
                                .font(.system(.subheadline, design: theme.fontDesign))
                            }
                        }
                    }
                }

                if let link = item.link {
                    Link(destination: link) {
                        ThemedPanel {
                            Label(theme.text("Open link"), systemImage: "safari")
                                .font(.system(.headline, design: theme.fontDesign))
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }

                ThemedLabel(text: "Screenshots").padding(.top, 8)
                // Full width. Tall screenshots start collapsed under a fade; a tap reveals the rest.
                let screenshots = item.sortedScreenshots
                ForEach(Array(screenshots.enumerated()), id: \.offset) { index, screenshot in
                    CollapsibleScreenshot(
                        assetID: screenshot.assetID,
                        isExpanded: expandedShots.contains(index),
                        // The first screenshot fills the screen down to the Delete button.
                        collapsedHeight: index == 0 ? firstShotHeight : 440,
                        onExpand: {
                            withAnimation(.smooth(duration: 0.45)) { _ = expandedShots.insert(index) }
                            // Reveal the rest by scrolling down to the screenshot's bottom edge as it grows.
                            Task {
                                try? await Task.sleep(for: .milliseconds(60))
                                withAnimation(.smooth(duration: 0.7)) { proxy.scrollTo("shot-\(index)", anchor: .bottom) }
                            }
                        },
                        onOpenFull: { viewer = .init(assetIDs: screenshots.map(\.assetID), start: index) }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        if let outline = theme.cardOutline {
                            RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(outline, lineWidth: 3)
                        }
                    }
                    .id("shot-\(index)")
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
                        if index == 0, firstShotTop == 0, top > 0 { firstShotTop = top }
                    }
                }

                // Spec §11: items sorted in the cloud are labelled, so the privacy promise stays honest.
                if item.processedInCloud {
                    Label("Sorted in the cloud with \(CloudProviderKind.forProviderID(item.processedBy)?.name ?? item.processedBy)", systemImage: "cloud")
                        .font(.system(.footnote, design: theme.fontDesign))
                        .foregroundStyle(theme.fadedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom)
        }
        }
        .themedNavigation(item.category.name)
        .safeAreaInset(edge: .bottom) {
            BottomBar(fade: theme.background) {
                WideButton(title: deleteTitle, systemImage: "trash", tint: .deleteRed) {
                    Task { await delete() }
                }
                .disabled(isDeleting)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { barTop = $0 }
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
