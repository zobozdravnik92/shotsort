import SwiftUI

/// A flat, saturated category card with big heavy type, styled after the reference designs.
struct CategoryCard: View {
    let summary: CategorySummary
    var isHero = false

    @Environment(\.theme) private var theme

    private var ink: Color { theme.cardInk(summary.category) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: theme.radius(28), style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                badge
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    status
                    if summary.actionCount > 0 {
                        ActionCountTag(count: summary.actionCount, ink: ink)
                    }
                }
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
        .background { shape.fill(theme.cardFill(summary.category)).themedShadow(theme) }
        .overlay {
            if let outline = theme.cardOutline {
                shape.strokeBorder(outline, lineWidth: theme.outlineWidth)
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
            ThemedTag(text: "\(summary.unreviewedCount) new", tint: theme.newTagTint, ink: ink, fill: theme.cardFill(summary.category))
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(theme.cardFill(summary.category))
                .frame(width: 26, height: 26)
                .background(theme.newTagTint == nil ? ink : Color.clear, in: Circle())
                .overlay { if theme.newTagTint != nil { Circle().strokeBorder(ink.opacity(0.3), lineWidth: 1) } }
        }
    }

    private var accessibilityText: String {
        let items = summary.itemCount == 1 ? "1 item" : "\(summary.itemCount) items"
        let new = summary.unreviewedCount > 0 ? ", \(summary.unreviewedCount) new" : ", all reviewed"
        let actions = summary.actionCount == 0 ? "" : summary.actionCount == 1 ? ", 1 action" : ", \(summary.actionCount) actions"
        return "\(summary.category.name), \(items)\(new)\(actions)"
    }
}

/// "4 actions": next steps Boost found. Outlined, so it reads apart from the filled "new" tag.
struct ActionCountTag: View {
    let count: Int
    let ink: Color
    @Environment(\.theme) private var theme

    var body: some View {
        ThemedTag(text: count == 1 ? "1 action" : "\(count) actions", tint: theme.actionTagTint, ink: ink, fill: .clear,
                  outlined: true, systemImage: "flame.fill")
    }
}

#Preview {
    VStack(spacing: 12) {
        CategoryCard(summary: .init(category: .other, itemCount: 14, screenshotCount: 14, unreviewedCount: 14), isHero: true)
            .frame(height: 230)
        HStack(spacing: 12) {
            CategoryCard(summary: .init(category: .jobs, itemCount: 3, screenshotCount: 3, unreviewedCount: 2, actionCount: 4))
                .frame(height: 240)
            CategoryCard(summary: .init(category: .receipts, itemCount: 1, screenshotCount: 1, unreviewedCount: 0))
                .frame(height: 160)
        }
    }
    .padding()
    .background(Theme.sunshine.background)
}
