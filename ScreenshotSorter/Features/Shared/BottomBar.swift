import SwiftUI

/// A bar pinned to the bottom of a screen, with the content fading out behind it.
/// Use with `.safeAreaInset(edge: .bottom)`.
struct BottomBar<Content: View>: View {
    var fade: Color = Color(.systemGroupedBackground)
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal)
            .padding(.top, 28)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background {
                LinearGradient(colors: [fade.opacity(0), fade], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            }
    }
}

/// The app's full-width button, like "Start triage" on Home.
struct WideButton: View {
    let title: String
    let systemImage: String
    /// nil uses the skin's accent.
    var tint: Color? = nil
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Label(theme.text(title), systemImage: systemImage)
                .font(.system(.headline, design: theme.fontDesign))
                .tracking(theme.uppercase ? 1 : 0)
                .foregroundStyle(tint == nil ? (theme.buttonInk ?? .white) : .white)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(tint ?? theme.buttonFill ?? theme.accent)
    }
}

#Preview {
    VStack {
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .safeAreaInset(edge: .bottom) {
        BottomBar {
            VStack(spacing: 12) {
                WideButton(title: "Start triage", systemImage: "rectangle.stack") {}
                WideButton(title: "Delete screenshot", systemImage: "trash", tint: .deleteRed) {}
            }
        }
    }
}
