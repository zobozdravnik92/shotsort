import SwiftUI

/// One item in a category list, as a card in the skin's style.
struct ItemRow: View {
    let item: Item

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
                    if item.status == .new {
                        Text(theme.text("New"))
                            .font(.system(size: 10, weight: .bold, design: theme.fontDesign))
                            .foregroundStyle(theme.cardFill(item.category))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(theme.cardInk(item.category), in: Capsule())
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
                                .overlay(Capsule().strokeBorder(theme.cardInk(item.category).opacity(0.5), lineWidth: 1.5))
                        }
                    }
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
