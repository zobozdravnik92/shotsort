import SwiftUI

/// Backlog progress: share of items already reviewed.
struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(fraction, format: .percent.precision(.fractionLength(0)))
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .animation(.smooth, value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sorted")
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview {
    ProgressRing(fraction: 0.73)
        .frame(width: 72, height: 72)
}
