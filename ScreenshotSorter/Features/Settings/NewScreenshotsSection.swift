import Photos
import UserNotifications
import SwiftUI

/// Photos access and new-screenshot alerts.
struct NewScreenshotsSection: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(NewScreenshots.alertsKey) private var alertsOn = true
    @State private var access = PhotoAccess.status
    @State private var notificationsAllowed = true

    var body: some View {
        Section {
            LabeledContent("Photos access", value: accessText)
            if access == .authorized {
                Toggle("Notify me about new screenshots", isOn: $alertsOn)
                if alertsOn && !notificationsAllowed {
                    Button("Allow notifications") { Task { await allowNotifications() } }
                }
            } else {
                Button("Change in Settings") { openSettings() }
            }
        } header: {
            Text("New screenshots")
        } footer: {
            Text(footerText)
        }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        .onChange(of: alertsOn) { _, on in
            guard on else { return }
            Task {
                notificationsAllowed = await NewScreenshots.requestNotificationPermission()
            }
        }
    }

    private var accessText: String {
        switch access {
        case .authorized: "Full"
        case .limited: "Some photos"
        default: "Off"
        }
    }

    private var footerText: String {
        switch access {
        case .authorized:
            "iOS lets the app look for new screenshots in the background a few times a day. New ones are sorted and you get a notification; tap it to start triage."
        case .limited:
            "With access to only some photos, new screenshots don't appear by themselves. Pull down on Home to refresh, or give full access to have them sorted automatically."
        default:
            "Photos access is off, so the app can't see your screenshots."
        }
    }

    private func refresh() async {
        access = PhotoAccess.status
        notificationsAllowed = await NewScreenshots.notificationsAllowed()
    }

    /// Asks iOS the first time; after a "no", only the Settings app can change it.
    private func allowNotifications() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .notDetermined {
            notificationsAllowed = await NewScreenshots.requestNotificationPermission()
        } else {
            openSettings()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
