import SwiftData
import SwiftUI

/// Which deck to open: everything, or one category.
struct TriageTarget: Identifiable {
    let id = UUID()
    let category: ItemCategory?
}

struct TriageView: View {
    let category: ItemCategory?

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var session: TriageSession?
    @State private var toast: Milestone?
    @State private var allClear: Milestone?
    @State private var result: TriageSession.SessionResult?
    @State private var isFinishing = false
    @State private var viewer: ScreenshotViewer.Target?

    var body: some View {
        VStack(spacing: 20) {
            if let session {
                TriageTopBar(session: session, isFinishing: isFinishing) {
                    Task { await finish() }
                }
                deck(session)
                controls(session)
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .padding()
        .background { ThemedBackground() }
        .overlay(alignment: .top) {
            if let toast {
                MilestoneToast(milestone: toast)
                    .padding(.top, 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if let allClear {
                AllClearView(milestone: allClear) {
                    withAnimation { self.allClear = nil }
                }
                .transition(.opacity)
            }
        }
        .sheet(item: $result, onDismiss: { dismiss() }) { outcome in
            SessionSummarySheet(result: outcome) { result = nil }
        }
        .fullScreenCover(item: $viewer) { target in
            ScreenshotViewer(
                target: target,
                onKeep: { handle(.keep) },
                onDelete: { handle(.delete) }
            )
        }
        .task {
            if session == nil {
                session = TriageSession(category: category, context: context, deleter: services.deleter)
            }
        }
    }

    private func deck(_ session: TriageSession) -> some View {
        ZStack {
            if let next = session.upcoming {
                TriageCard(item: next)
                    .scaleEffect(0.95)
                    .offset(y: 14)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            if let current = session.current {
                SwipeableCard(
                    item: current,
                    onSwipe: { handle($0) },
                    onTap: { viewer = .init(assetIDs: current.sortedScreenshots.map(\.assetID)) }
                )
                .id(current.persistentModelID)
            } else {
                ContentUnavailableView(
                    "All reviewed",
                    systemImage: "checkmark.circle",
                    description: Text("Tap Done to wrap up and free the space.")
                )
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func controls(_ session: TriageSession) -> some View {
        HStack(spacing: 112) {
            CircleButton(systemImage: "xmark", color: .red, label: "Delete", size: 64) {
                handle(.delete)
            }
            .disabled(session.current == nil)

            CircleButton(systemImage: "checkmark", color: .green, label: "Keep", size: 64) {
                handle(.keep)
            }
            .disabled(session.current == nil)
        }
        .disabled(isFinishing)
    }

    private func handle(_ decision: TriageSession.Decision) {
        guard let session, session.current != nil else { return }
        switch decision {
        case .keep: Haptics.keep()
        case .delete: Haptics.delete()
        }
        let milestones = session.swipe(decision)
        for milestone in milestones { show(milestone) }
    }

    private func show(_ milestone: Milestone) {
        Haptics.milestone()
        // Streaks (10, 25, 50…) and all-clear moments get the full-screen congrats popup.
        if milestone.isCelebration {
            // Stays until dismissed, so it's never missed.
            withAnimation(.spring(duration: 0.4)) { allClear = milestone }
        } else {
            withAnimation(.spring(duration: 0.35)) { toast = milestone }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { if toast == milestone { toast = nil } }
            }
        }
    }

    private func finish() async {
        guard let session, !isFinishing else { return }
        isFinishing = true
        let outcome = await session.finish()
        isFinishing = false
        if outcome.reviewed == 0 && !outcome.deletesCancelled {
            dismiss()
        } else {
            result = outcome
        }
    }
}

/// Live counters and the Done button.
private struct TriageTopBar: View {
    let session: TriageSession
    let isFinishing: Bool
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // One counter: every keep or delete adds one.
            Counter(value: "\(session.reviewedCount)", label: "sorted")
            Spacer(minLength: 4)
            Button(action: onDone) {
                if isFinishing {
                    ProgressView()
                } else {
                    Text("Done").bold().lineLimit(1)
                }
            }
            .buttonStyle(.bordered)
            .fixedSize()
            .disabled(isFinishing)
        }
    }
}

private struct Counter: View {
    let value: String
    let label: String
    @Environment(\.theme) private var theme

    var body: some View {
        // A pill: value then label, in the skin's card style.
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: theme.fontDesign).monospacedDigit())
                .contentTransition(.numericText())
            Text(theme.text(label))
                .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                .opacity(0.85)
        }
        .lineLimit(1)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        // A slightly darker shade of the screen background, no border.
        .background(theme.background.mix(with: .black, by: 0.18), in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TriageView(category: nil)
        .environment(AppServices.preview)
        .modelContainer(AppServices.preview.container)
}
