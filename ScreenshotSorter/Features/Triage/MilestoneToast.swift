import SwiftUI

/// Small toast for streaks.
struct MilestoneToast: View {
    let milestone: Milestone

    var body: some View {
        Label(milestone.message, systemImage: "flame.fill")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// Full-screen moment when a category reaches zero unreviewed. Confetti comes with polish later.
struct AllClearView: View {
    let milestone: Milestone
    let onDismiss: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(theme.ink)
                    .symbolEffect(.bounce, options: .nonRepeating)
                Text(theme.text("Congrats!"))
                    .font(theme.font(36))
                    .tracking(theme.tracking(36))
                    .foregroundStyle(theme.ink)
                Text(milestone.message)
                    .font(.system(.title3, design: theme.fontDesign).weight(.semibold))
                    .foregroundStyle(theme.ink.opacity(0.8))
                    .multilineTextAlignment(.center)
                WideButton(title: "Keep going", systemImage: "arrow.right", action: onDismiss)
                    .padding(.top, 12)
            }
            .padding(32)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to continue")
    }
}

#Preview {
    VStack(spacing: 40) {
        MilestoneToast(milestone: .streak(10))
        AllClearView(milestone: .allClear(.jobs)) {}
            .frame(height: 300)
    }
}
