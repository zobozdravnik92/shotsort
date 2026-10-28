import SwiftUI

/// Full-screen source screenshots, swipeable when an item has several.
struct ScreenshotViewer: View {
    struct Target: Identifiable {
        let id = UUID()
        let assetIDs: [String]
        var start = 0
    }

    let target: Target
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
        }
        .onAppear { selection = target.start }
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
    ScreenshotViewer(target: .init(assetIDs: ["preview-0", "preview-1"]))
        .environment(AppServices.preview)
}
