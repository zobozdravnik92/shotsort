import SwiftUI

struct CategoryCard: View {
    let category: ItemCategory
    let itemCount: Int
    let unreviewedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Spacer()
                if unreviewedCount > 0 {
                    Text("\(unreviewedCount) new")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.15), in: Capsule())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("All reviewed")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    HStack {
        CategoryCard(category: .jobs, itemCount: 42, unreviewedCount: 12)
        CategoryCard(category: .receipts, itemCount: 3, unreviewedCount: 0)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
