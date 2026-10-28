import SwiftUI

struct SessionSummarySheet: View {
    let result: TriageSession.SessionResult
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: result.deletesCancelled ? "arrow.uturn.backward.circle.fill" : "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(result.deletesCancelled ? "Nothing was deleted" : "Nice session")
                    .font(.title.bold())
                if result.deletesCancelled {
                    Text("You cancelled the delete, so those screenshots are back in your pile.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if let milestone = result.spaceMilestone {
                    Text(milestone.message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 12) {
                StatTile(value: "\(result.reviewed)", label: "Reviewed")
                StatTile(value: "\(result.deleted)", label: "Deleted")
                StatTile(value: ByteText.short(result.bytesFreed), label: "Freed")
            }

            Button(action: onDone) {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SessionSummarySheet(
            result: .init(reviewed: 48, deleted: 31, bytesFreed: 104_000_000, deletesCancelled: false, spaceMilestone: .spaceFreed(bytes: 100_000_000)),
            onDone: {}
        )
    }
}
