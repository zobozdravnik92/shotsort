import SwiftUI

/// What one item looks like in the triage deck.
struct TriageCard: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(item.category.name, systemImage: item.category.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(item.title)
                .font(.title2.bold())
                .lineLimit(3)
            FieldRows(item: item, limit: 4)
            if !item.summary.isEmpty {
                Text(item.summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            Spacer(minLength: 0)
            ThumbnailView(assetID: item.sortedScreenshots.first?.assetID)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            HStack {
                Text(item.savedAt, format: .dateTime.day().month().year())
                Spacer()
                Text("Tap to see the screenshot")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            // Shadow on the shape only, so it doesn't blur behind the text.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        }
    }
}

/// The top card: follows the finger, tilts, tints green or red, and flies off past the threshold.
struct SwipeableCard: View {
    let item: Item
    let onSwipe: (TriageSession.Decision) -> Void
    let onTap: () -> Void

    @State private var offset: CGSize = .zero
    private let threshold: CGFloat = 110

    private var progress: Double { min(abs(offset.width) / threshold, 1) }

    var body: some View {
        TriageCard(item: item)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(offset.width >= 0 ? Color.green : Color.red)
                    .opacity(progress * 0.22)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: offset.width >= 0 ? .topLeading : .topTrailing) {
                Text(offset.width >= 0 ? "KEEP" : "DELETE")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(offset.width >= 0 ? Color.green : Color.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(Capsule().strokeBorder(offset.width >= 0 ? Color.green : Color.red, lineWidth: 2))
                    .padding(20)
                    .opacity(progress)
                    .allowsHitTesting(false)
            }
            .rotationEffect(.degrees(Double(offset.width / 18)), anchor: .bottom)
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { offset = $0.translation }
                    .onEnded { value in
                        let travel = value.translation.width
                        let flick = value.predictedEndTranslation.width
                        if travel > threshold || flick > threshold * 2.5 {
                            flyOff(.keep)
                        } else if travel < -threshold || flick < -threshold * 2.5 {
                            flyOff(.delete)
                        } else {
                            withAnimation(.spring(duration: 0.3, bounce: 0.35)) { offset = .zero }
                        }
                    }
            )
            .onTapGesture(perform: onTap)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Swipe right to keep, left to delete. Double-tap to see the screenshot.")
            .accessibilityAction(named: "Keep") { onSwipe(.keep) }
            .accessibilityAction(named: "Delete") { onSwipe(.delete) }
    }

    private func flyOff(_ decision: TriageSession.Decision) {
        let direction: CGFloat = decision == .keep ? 1 : -1
        withAnimation(.easeOut(duration: 0.2)) {
            offset = CGSize(width: direction * 700, height: offset.height + 60)
        } completion: {
            onSwipe(decision)
        }
    }
}

#Preview {
    SwipeableCard(item: SampleData.firstItem(in: AppServices.preview.container.mainContext), onSwipe: { _ in }, onTap: {})
        .padding()
        .frame(height: 560)
        .background(Color(.systemGroupedBackground))
        .environment(AppServices.preview)
}
