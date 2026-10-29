import SwiftUI

/// A faint dot grid, like the surface in the reference design.
struct DotGrid: View {
    var spacing: CGFloat = 16
    var dotSize: CGFloat = 1.6
    var color: Color = .primary.opacity(0.12)

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    path.addEllipse(in: CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize))
                    x += spacing
                }
                y += spacing
            }
            context.fill(path, with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A screen background for the current skin.
struct ThemedBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.background
            if let dotColor = theme.dotColor {
                DotGrid(spacing: 14, dotSize: 4, color: dotColor)
            }
        }
        .ignoresSafeArea()
    }
}
