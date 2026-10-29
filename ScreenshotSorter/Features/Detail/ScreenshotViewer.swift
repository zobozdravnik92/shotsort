import SwiftUI

/// Full-screen source screenshots, swipeable when an item has several.
struct ScreenshotViewer: View {
    struct Target: Identifiable {
        let id = UUID()
        let assetIDs: [String]
        var start = 0
    }

    let target: Target
    /// Keep and delete act on the item being viewed. The viewer closes first, then the action runs.
    var onKeep: (() -> Void)?
    var onDelete: (() -> Void)?
    var keepDisabled = false
    /// Used when there's only a delete action (from item detail), shown as one wide button.
    var deleteTitle = "Delete screenshot"

    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(target.assetIDs.enumerated()), id: \.offset) { index, assetID in
                    ScrollView {
                        FullImage(assetID: assetID)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: target.assetIDs.count > 1 ? .automatic : .never))
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if let onKeep, let onDelete {
                    triageActions(keep: onKeep, delete: onDelete)
                } else if let onDelete {
                    BottomBar(fade: .black) {
                        WideButton(title: deleteTitle, systemImage: "trash", tint: .deleteRed) {
                            dismiss()
                            onDelete()
                        }
                    }
                }
            }
        }
        .onAppear { selection = target.start }
    }

    /// From triage: same round buttons and spacing as the deck, delete left, keep right.
    private func triageActions(keep: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        BottomBar(fade: .black) {
            HStack(spacing: 112) {
                CircleButton(systemImage: "xmark", color: .red, label: "Delete", size: 64) {
                    dismiss()
                    delete()
                }
                CircleButton(systemImage: "checkmark", color: .green, label: "Keep", size: 64) {
                    dismiss()
                    keep()
                }
                .disabled(keepDisabled)
            }
        }
    }
}

private struct FullImage: View {
    let assetID: String
    @Environment(AppServices.self) private var services
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Screenshot")
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .task {
            if let cgImage = await services.source(for: assetID).image(for: assetID, maxWidth: 1_320) {
                image = UIImage(cgImage: cgImage)
            }
        }
    }
}

#Preview {
    ScreenshotViewer(target: .init(assetIDs: ["preview-0", "preview-1"]), onDelete: {})
        .environment(AppServices.preview)
}
