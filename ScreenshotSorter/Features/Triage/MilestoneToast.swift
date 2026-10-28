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

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .symbolEffect(.bounce, options: .nonRepeating)
                Text(milestone.message)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
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
