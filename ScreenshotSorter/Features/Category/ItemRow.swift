import SwiftUI

/// One item in a category list, as a card in the skin's style.
struct ItemRow: View {
    let item: Item
    /// Matching screenshot text, shown in search results.
    var snippet: String? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        ThemedPanel(category: item.category, padding: 13, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(theme.text(item.title))
                        .font(theme.font(16))
                        .tracking(theme.tracking(16))
                        .lineSpacing(theme.wrapSpacing)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if !item.actions.isEmpty {
                        ActionCountTag(count: item.actions.count, ink: theme.cardInk(item.category))
                    }
                    if item.status == .new {
                        ThemedTag(text: "New", tint: theme.newTagTint, ink: theme.cardInk(item.category), fill: theme.cardFill(item.category))
                    }
                }
                if !item.keyFieldValues.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(item.keyFieldValues.prefix(3).enumerated()), id: \.offset) { _, value in
                            Text(theme.text(value))
                                .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                // Hairline skins get the reference's quiet grey chip; poster skins keep a bold outline.
                                .background(theme.outlineWidth < 2 ? theme.cardInk(item.category).opacity(0.06) : .clear, in: Capsule())
                                .overlay(Capsule().strokeBorder(theme.cardInk(item.category).opacity(theme.outlineWidth < 2 ? 0.14 : 0.5),
                                                                lineWidth: theme.outlineWidth < 2 ? 1 : 1.5))
                        }
                    }
                }
                if let snippet {
                    Text("“\(snippet)”")
                        .font(.system(size: 13, design: theme.fontDesign))
                        .lineLimit(2)
                        .opacity(0.75)
                }
                Text(item.savedAt, format: .dateTime.day().month().year())
                    .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                    .opacity(0.6)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ItemRow(item: SampleData.firstItem(in: AppServices.preview.container.mainContext))
        .padding()
        .background(Theme.sunshine.background)
        .environment(AppServices.preview)
        .modelContainer(AppServices.preview.container)
}
