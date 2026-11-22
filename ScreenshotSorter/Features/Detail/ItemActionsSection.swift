import EventKit
import EventKitUI
import SwiftData
import SwiftUI
import UserNotifications

/// Next steps Boost found for an item. Doing or dismissing one removes it, which lowers the count on Home.
struct ItemActionsSection: View {
    let item: Item

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme
    @State private var calendarAction: ItemAction?
    @State private var message: String?

    var body: some View {
        let actions = item.actions
        if !actions.isEmpty {
            ThemedLabel(text: actions.count == 1 ? "1 action" : "\(actions.count) actions").padding(.top, 8)
            // One card per action, so each reads as its own thing to do.
            VStack(spacing: 8) {
                ForEach(actions) { action in
                    ThemedPanel(category: item.category, padding: 14, cornerRadius: 20) {
                        row(action)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                if let message {
                    Text(message)
                        .font(.system(.footnote, design: theme.fontDesign))
                        .foregroundStyle(theme.fadedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .sheet(item: $calendarAction) { action in
                AddToCalendarSheet(title: action.title, day: action.day ?? .now, notes: item.title) { added in
                    calendarAction = nil
                    if added { done(action, message: "Added to your calendar.") }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func row(_ action: ItemAction) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol(for: action.kind))
                .font(.system(size: 15, weight: .bold))
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(theme.cardInk(item.category), lineWidth: 1.5))
                .accessibilityHidden(true)

            Button { perform(action) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.text(action.title))
                        .font(.system(.subheadline, design: theme.fontDesign).weight(.semibold))
                        .multilineTextAlignment(.leading)
                    if let day = action.day {
                        Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.system(.caption, design: theme.fontDesign))
                            .opacity(0.65)
                    } else if action.kind == .draft, let text = action.detail {
                        Text(text)
                            .font(.system(.caption, design: theme.fontDesign))
                            .lineLimit(2)
                            .opacity(0.65)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button("Dismiss", systemImage: "xmark") { done(action, message: nil) }
                .labelStyle(.iconOnly)
                .font(.system(size: 13, weight: .bold))
                .opacity(0.5)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
        }
    }

    private func symbol(for kind: ItemAction.Kind) -> String {
        switch kind {
        case .reminder: "bell"
        case .calendar: "calendar.badge.plus"
        case .draft: "square.and.pencil"
        case .open: "safari"
        }
    }

    private func perform(_ action: ItemAction) {
        switch action.kind {
        case .calendar:
            calendarAction = action
        case .reminder:
            Task { await remind(action) }
        case .draft:
            UIPasteboard.general.string = action.detail
            done(action, message: "Copied. Paste it wherever you want to send it.")
        case .open:
            guard let link = action.detail, let url = linkURL(link) else { return }
            openURL(url)
            done(action, message: nil)
        }
    }

    private func linkURL(_ text: String) -> URL? {
        let candidate = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: candidate), url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }

    /// A notification at 9:00 on the day, or in an hour if that's already passed.
    private func remind(_ action: ItemAction) async {
        guard let day = action.day else { return }
        let allowed = await NewScreenshots.notificationsAllowed() ? true : await NewScreenshots.requestNotificationPermission()
        guard allowed else {
            message = "Turn on notifications for this app in Settings to get reminders."
            return
        }
        var fireAt = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        if fireAt < .now { fireAt = .now.addingTimeInterval(3_600) }

        let content = UNMutableNotificationContent()
        content.title = action.title
        content.body = item.title
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let request = UNNotificationRequest(
            identifier: "action-\(item.id.uuidString)-\(action.id.hashValue)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            done(action, message: "Reminder set for \(fireAt.formatted(.dateTime.weekday(.wide).day().month().hour().minute())).")
        } catch {
            message = "Couldn't set the reminder."
        }
    }

    private func done(_ action: ItemAction, message: String?) {
        withAnimation(.snappy) {
            item.removeAction(action)
            self.message = message
        }
        context.saveOrLog()
    }
}

/// Apple's own "add event" screen. Needs no calendar permission: the person adds the event themselves.
private struct AddToCalendarSheet: UIViewControllerRepresentable {
    let title: String
    let day: Date
    let notes: String
    let onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.isAllDay = true
        event.startDate = day
        event.endDate = day
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onFinish(action == .saved)
        }
    }
}
