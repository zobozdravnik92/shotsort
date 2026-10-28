import SwiftUI

/// Up to three short field values as capsules.
struct FieldChips: View {
    let values: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(values.prefix(3).enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
    }
}

/// Label and value rows for an item's fields.
struct FieldRows: View {
    let item: Item
    var limit = Int.max

    var body: some View {
        let keys = item.category.fieldKeys.filter { item.displayValue(for: $0) != nil }.prefix(limit)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(keys), id: \.self) { key in
                HStack(alignment: .firstTextBaseline) {
                    Text(ItemCategory.fieldLabel(key))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(item.displayValue(for: key) ?? "")
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
            }
        }
    }
}

#Preview {
    FieldChips(values: ["Acme Pay", "Hybrid", "€85–100k"])
        .padding()
}
