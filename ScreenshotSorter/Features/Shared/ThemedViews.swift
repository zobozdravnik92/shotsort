import SwiftUI

/// Big skin-styled type with a faded second line, used at the top of every main screen.
struct ScreenHeader: View {
    let title: String
    var subtitle: String?
    var size: CGFloat = 36

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.lineGap) {
            Text(theme.text(title))
                .foregroundStyle(theme.ink)
            if let subtitle {
                Text(theme.text(subtitle))
                    .foregroundStyle(theme.fadedInk)
            }
        }
        .font(theme.font(size))
        .tracking(theme.tracking(size))
        .lineSpacing(theme.wrapSpacing)
        .lineLimit(2)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A rounded panel in the skin's card style. `category` picks the card colour; nil uses the neutral one.
struct ThemedPanel<Content: View>: View {
    var category: ItemCategory = .other
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    @Environment(\.theme) private var theme
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 24, style: .continuous) }

    var body: some View {
        content
            .foregroundStyle(theme.cardInk(category))
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardFill(category), in: shape)
            .overlay {
                if let outline = theme.cardOutline {
                    shape.strokeBorder(outline, lineWidth: 3)
                }
            }
    }
}

/// Small section label above a panel, in the skin's type.
struct ThemedLabel: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(theme.text(text))
            .font(.system(size: 13, weight: .bold, design: theme.fontDesign))
            .tracking(theme.uppercase ? 1.2 : 0)
            .foregroundStyle(theme.fadedInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }
}

extension View {
    /// Hides the system navigation title so the big themed header stands alone, and themes the bar.
    func themedNavigation(_ title: String) -> some View {
        modifier(ThemedNavigation(title: title))
    }
}

private struct ThemedNavigation: ViewModifier {
    let title: String
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background { ThemedBackground() }
    }
}
