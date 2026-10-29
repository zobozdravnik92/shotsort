import SwiftUI

/// A screenshot image, filled from the top so the start of the screen shows.
struct ThumbnailView: View {
    let assetID: String?
    var maxWidth: CGFloat = 600

    @Environment(AppServices.self) private var services
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay(alignment: .top) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: assetID) {
                guard let assetID else { return }
                if let cgImage = await services.source(for: assetID).image(for: assetID, maxWidth: maxWidth) {
                    image = UIImage(cgImage: cgImage)
                }
            }
            .accessibilityHidden(true)
    }
}

/// A screenshot at full width and its natural height.
struct FullWidthScreenshot: View {
    let assetID: String

    @Environment(AppServices.self) private var services
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size, contentMode: .fit)
            } else {
                // A phone-shaped placeholder while it loads.
                Rectangle()
                    .fill(.quaternary)
                    .aspectRatio(9.0 / 19.5, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: assetID) {
            if let cgImage = await services.source(for: assetID).image(for: assetID, maxWidth: 1_200) {
                image = UIImage(cgImage: cgImage)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A full-width screenshot that starts cropped under a fade when it's tall.
/// The first tap expands it; once fully shown, a tap opens it full screen.
struct CollapsibleScreenshot: View {
    let assetID: String
    let isExpanded: Bool
    var collapsedHeight: CGFloat = 440
    let onExpand: () -> Void
    let onOpenFull: () -> Void

    @Environment(AppServices.self) private var services
    @Environment(\.theme) private var theme
    @State private var image: UIImage?
    @State private var width: CGFloat = 0

    private var naturalHeight: CGFloat? {
        guard let image, width > 0, image.size.width > 0 else { return nil }
        return width * image.size.height / image.size.width
    }

    /// Only crop when there's a meaningful amount hidden.
    private var isTall: Bool { (naturalHeight ?? 0) > collapsedHeight + 60 }
    private var isCollapsed: Bool { isTall && !isExpanded }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image, let naturalHeight {
                    // Always full width at its natural height; the frame below crops the bottom when collapsed.
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: width, height: naturalHeight)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isCollapsed ? collapsedHeight : (naturalHeight ?? collapsedHeight), alignment: .top)
            .clipped()

            if isCollapsed {
                LinearGradient(
                    colors: [theme.background.opacity(0), theme.background.opacity(0.85), theme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                .allowsHitTesting(false)

                Text("Click to view full")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    .padding(.bottom, 22)
                    .transition(.opacity)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            if isCollapsed { onExpand() } else { onOpenFull() }
        }
        .task(id: assetID) {
            if let cgImage = await services.source(for: assetID).image(for: assetID, maxWidth: 1_200) {
                image = UIImage(cgImage: cgImage)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Screenshot")
        .accessibilityHint(isCollapsed ? "Shows the full screenshot" : "Opens the screenshot full screen")
        .accessibilityAddTraits(.isButton)
    }
}
