import SwiftUI

/// Press and hold a card to preview its screenshot; while still holding, flick to delete.
enum Peek {
    /// +1: flick right deletes. -1 would match triage, where left deletes.
    static let deleteDirection: CGFloat = 1
    /// Short enough to feel instant, long enough that a quick tap still opens the card.
    static let holdDuration = 0.12
    static let threshold: CGFloat = 110

    /// A long drag, or a quick flick, toward the delete side. A flick counts by where the card
    /// was heading (its position plus a moment of momentum), like iOS judges swipes.
    static func isDelete(translation: CGFloat, velocity: CGFloat) -> Bool {
        let travel = translation * deleteDirection
        let projected = travel + velocity * deleteDirection * 0.2
        return travel > threshold || (travel > 30 && projected > threshold * 1.5)
    }
}

/// Press and hold, then drag, using UIKit's long-press recognizer. Unlike a SwiftUI
/// long-press-then-drag gesture, it lets the list scroll when the finger moves before the hold.
struct PressAndDragGesture: UIGestureRecognizerRepresentable {
    var onBegan: () -> Void
    var onChanged: (CGSize) -> Void
    /// Translation and horizontal speed (points per second) when the finger lifts.
    var onEnded: (CGSize, CGFloat) -> Void
    var onCancelled: () -> Void

    final class Coordinator {
        var start: CGPoint = .zero
        /// Recent finger positions, used to measure how fast it was moving when it lifted.
        var samples: [(x: CGFloat, time: TimeInterval)] = []

        func record(_ x: CGFloat, at time: TimeInterval) {
            samples.append((x, time))
            samples.removeAll { time - $0.time > 0.12 }
        }

        /// Horizontal speed over the last ~0.1 s, in points per second.
        var velocityX: CGFloat {
            guard let first = samples.first, let last = samples.last else { return 0 }
            let elapsed = max(last.time - first.time, 0.016)
            return (last.x - first.x) / elapsed
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = Peek.holdDuration
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let point = context.converter.location(in: .global)
        let now = ProcessInfo.processInfo.systemUptime
        let state = context.coordinator
        let translation = CGSize(width: point.x - state.start.x, height: point.y - state.start.y)
        switch recognizer.state {
        case .began:
            state.start = point
            state.samples = [(point.x, now)]
            onBegan()
        case .changed:
            state.record(point.x, at: now)
            onChanged(translation)
        case .ended:
            // A finger that stopped before lifting isn't a flick.
            let stalled = now - (state.samples.last?.time ?? now) > 0.08
            state.record(point.x, at: now)
            onEnded(translation, stalled ? 0 : state.velocityX)
        case .cancelled, .failed:
            onCancelled()
        default:
            break
        }
    }
}

/// The screenshot shown while a card is held. It follows the finger and turns red toward delete.
struct PeekOverlay: View {
    let item: Item
    let offset: CGSize

    private var towardDelete: Double {
        max(0, min(offset.width * Peek.deleteDirection / Peek.threshold, 1))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            if let assetID = item.sortedScreenshots.first?.assetID {
                FittedScreenshot(assetID: assetID)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.deleteRed)
                            .opacity(towardDelete * 0.3)
                    }
                    .overlay(alignment: Peek.deleteDirection > 0 ? .topLeading : .topTrailing) {
                        Text("DELETE")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.deleteRed, in: Capsule())
                            .padding(16)
                            .opacity(towardDelete)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 60)
                    .rotationEffect(.degrees(Double(offset.width / 18)), anchor: .bottom)
                    .offset(offset)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A whole screenshot scaled to fit the space it's given.
private struct FittedScreenshot: View {
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
                Rectangle()
                    .fill(.quaternary)
                    .aspectRatio(9.0 / 19.5, contentMode: .fit)
            }
        }
        .task(id: assetID) {
            if let cgImage = await services.source(for: assetID).image(for: assetID, maxWidth: 1_000) {
                image = UIImage(cgImage: cgImage)
            }
        }
    }
}
