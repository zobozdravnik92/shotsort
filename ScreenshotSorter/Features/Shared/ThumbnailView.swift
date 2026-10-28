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
