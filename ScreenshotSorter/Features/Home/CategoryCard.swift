import SwiftUI

/// A flat, saturated category card with big heavy type, styled after the reference designs.
struct CategoryCard: View {
    let summary: CategorySummary
    var isHero = false

    @Environment(\.theme) private var theme

    private var ink: Color { theme.cardInk(summary.category) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                badge
                Spacer(minLength: 8)
                status
            }
            Spacer(minLength: 6)
            Text("\(summary.itemCount)")
                .font(theme.font(isHero ? 52 : 40))
                .monospacedDigit()
                .tracking(theme.tracking(isHero ? 52 : 40))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.bottom, max(theme.lineGap, 0) / 2)
            Text(theme.text(summary.category.name))
                // Same size on every card, whatever its height.
                .font(theme.font(14))
                .tracking(theme.tracking(14))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(ink)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.cardFill(summary.category), in: shape)
        .overlay {
            if let outline = theme.cardOutline {
                shape.strokeBorder(outline, lineWidth: 3)
            }
        }
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    /// A black ring with the category symbol, like the transit-map circles in the references.
    private var badge: some View {
        Image(systemName: summary.category.symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(ink)
            .frame(width: 32, height: 32)
            .overlay(Circle().strokeBorder(ink, lineWidth: 1.5))
    }

    @ViewBuilder
    private var status: some View {
        if summary.unreviewedCount > 0 {
            Text(theme.text("\(summary.unreviewedCount) new"))
                .font(.system(size: 12, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.cardFill(summary.category))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(ink, in: Capsule())
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(theme.cardFill(summary.category))
                .frame(width: 26, height: 26)
                .background(ink, in: Circle())
        }
    }

    private var accessibilityText: String {
        let items = summary.itemCount == 1 ? "1 item" : "\(summary.itemCount) items"
        let new = summary.unreviewedCount > 0 ? ", \(summary.unreviewedCount) new" : ", all reviewed"
        return "\(summary.category.name), \(items)\(new)"
    }
}

#Preview {
    VStack(spacing: 12) {
        CategoryCard(summary: .init(category: .other, itemCount: 14, screenshotCount: 14, unreviewedCount: 14), isHero: true)
            .frame(height: 230)
        HStack(spacing: 12) {
            CategoryCard(summary: .init(category: .jobs, itemCount: 3, screenshotCount: 3, unreviewedCount: 2))
                .frame(height: 240)
            CategoryCard(summary: .init(category: .receipts, itemCount: 1, screenshotCount: 1, unreviewedCount: 0))
                .frame(height: 160)
        }
    }
    .padding()
    .background(Theme.sunshine.background)
}
