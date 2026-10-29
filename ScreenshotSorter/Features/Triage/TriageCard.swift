import SwiftUI

/// What one item looks like in the triage deck.
struct TriageCard: View {
    let item: Item

    @Environment(\.theme) private var theme
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and summary sit tight together; details follow.
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.text(item.title))
                    .font(theme.font(22))
                    .tracking(theme.tracking(22))
                    .lineSpacing(theme.wrapSpacing)
                    .lineLimit(2)
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.system(.subheadline, design: theme.fontDesign))
                        .opacity(0.75)
                        .lineLimit(2)
                }
            }
            VStack(spacing: 4) {
                ForEach(item.category.fieldKeys.filter { item.displayValue(for: $0) != nil }.prefix(4), id: \.self) { key in
                    HStack(alignment: .firstTextBaseline) {
                        Text(theme.text(ItemCategory.fieldLabel(key))).opacity(0.6)
                        Spacer(minLength: 12)
                        Text(item.displayValue(for: key) ?? "").multilineTextAlignment(.trailing)
                    }
                    .font(.system(.subheadline, design: theme.fontDesign))
                }
            }
            // The screenshot fills the rest of the card, so it can be read without opening it.
            ThumbnailView(assetID: item.sortedScreenshots.first?.assetID, maxWidth: 900)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 4)
        }
        .foregroundStyle(theme.cardInk(item.category))
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            // Shadow on the shape only, so it doesn't blur behind the text.
            shape
                .fill(theme.cardFill(item.category))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        }
        .overlay {
            if let outline = theme.cardOutline {
                shape.strokeBorder(outline, lineWidth: 3)
            }
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
        .background(Theme.sunshine.background)
        .environment(AppServices.preview)
}
