import SwiftUI

/// The round keep / delete / undo button used in triage and item detail.
struct CircleButton: View {
    let systemImage: String
    let color: Color
    let label: String
    let size: CGFloat
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    HStack(spacing: 32) {
        CircleButton(systemImage: "xmark", color: .red, label: "Delete", size: 64) {}
        CircleButton(systemImage: "arrow.uturn.backward", color: .gray, label: "Undo", size: 48) {}
            .disabled(true)
        CircleButton(systemImage: "checkmark", color: .green, label: "Keep", size: 64) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
