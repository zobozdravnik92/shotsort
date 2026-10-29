import SwiftUI

/// One item in a category list, as a card in the skin's style.
struct ItemRow: View {
    let item: Item

    @Environment(\.theme) private var theme

    var body: some View {
        ThemedPanel(category: item.category) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text(theme.text(item.title))
                        .font(theme.font(19))
                        .tracking(theme.tracking(19))
                        .lineSpacing(theme.wrapSpacing)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if item.status == .new {
                        Text(theme.text("New"))
                            .font(.system(size: 11, weight: .bold, design: theme.fontDesign))
                            .foregroundStyle(theme.cardFill(item.category))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.cardInk(item.category), in: Capsule())
                    }
                }
                if !item.keyFieldValues.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(item.keyFieldValues.prefix(3).enumerated()), id: \.offset) { _, value in
                            Text(theme.text(value))
                                .font(.system(size: 12, weight: .semibold, design: theme.fontDesign))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .overlay(Capsule().strokeBorder(theme.cardInk(item.category).opacity(0.5), lineWidth: 1.5))
                        }
                    }
                }
                Text(item.savedAt, format: .dateTime.day().month().year())
                    .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
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
