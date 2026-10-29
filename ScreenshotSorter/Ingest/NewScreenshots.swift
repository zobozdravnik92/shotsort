import BackgroundTasks
import Foundation
import OSLog
import Observation
import Photos
import PhotosUI
import UIKit
import UserNotifications

/// How the app finds new screenshots, depending on Photos access:
/// - Full access: iOS wakes the app now and then; new screenshots are sorted and a notification is sent.
/// - Limited access: only screenshots the user shared are visible, so the user refreshes by hand.
/// - Either way: the app checks every time it opens, and while it's open.
enum NewScreenshots {
    static let taskIdentifier = "com.rokpremuz.ScreenshotSorter.newScreenshots"
    static let alertsKey = "alerts.newScreenshots"
    /// iOS decides the actual time; this is only the earliest it may run.
    static let checkInterval: TimeInterval = 30 * 60

    /// Asks iOS for the next background check.
    static func scheduleBackgroundCheck() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: checkInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func shouldNotify(access: PHAuthorizationStatus, alertsOn: Bool, newCount: Int) -> Bool {
        access == .authorized && alertsOn && newCount > 0
    }

    static func notificationText(newCount: Int) -> (title: String, body: String) {
        let body = newCount == 1
            ? "1 new screenshot is sorted and ready to triage."
            : "\(newCount) new screenshots are sorted and ready to triage."
        return ("New screenshots", body)
    }

    // MARK: Notifications

    static func requestNotificationPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func notificationsAllowed() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    static func postNotification(newCount: Int) async {
        let text = notificationText(newCount: newCount)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.userInfo = ["action": "triage"]
        // One notification at a time: a newer one replaces the old.
        let request = UNNotificationRequest(identifier: "new-screenshots", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// Carries a notification tap to Home, which opens triage.
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()
    /// Changes each time a "new screenshots" notification is tapped.
    private(set) var triageRequest: UUID?

    func requestTriage() { triageRequest = UUID() }
    func consume() { triageRequest = nil }
}

/// Handles notification taps and shows notifications while the app is open.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let isTriage = response.notification.request.content.userInfo["action"] as? String == "triage"
        Logger(subsystem: "com.rokpremuz.ScreenshotSorter", category: "Notifications").info("Notification tapped, opens triage: \(isTriage, privacy: .public)")
        guard isTriage else { return }
        await MainActor.run { NotificationRouter.shared.requestTriage() }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// Tells the app when the Photos library changes while it's running, so new screenshots show up without reopening.
final class PhotoLibraryWatcher: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let onChange: @MainActor @Sendable () -> Void

    init(onChange: @escaping @MainActor @Sendable () -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [onChange] in onChange() }
    }
}

extension PhotoAccess {
    static var isFull: Bool { status == .authorized }
    static var isLimited: Bool { status == .limited }

    /// Lets a limited-access user share more screenshots. Returns when the picker closes.
    @MainActor
    static func presentLimitedPicker() async {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top) { _ in
                continuation.resume()
            }
        }
    }
}
