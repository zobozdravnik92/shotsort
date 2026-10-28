import SwiftUI

struct ItemRow: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if item.status == .new {
                    Circle()
                        .fill(.tint)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("New")
                }
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
            }
            if !item.keyFieldValues.isEmpty {
                FieldChips(values: item.keyFieldValues)
            }
            Text(item.savedAt, format: .dateTime.day().month().year())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ItemRow(item: SampleData.firstItem(in: AppServices.preview.container.mainContext))
    }
    .environment(AppServices.preview)
    .modelContainer(AppServices.preview.container)
}
