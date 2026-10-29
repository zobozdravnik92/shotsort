import CoreText
import SwiftData
import SwiftUI

@main
struct ScreenshotSorterApp: App {
    @State private var services = AppServices()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Self.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
        }
        .modelContainer(services.container)
        // iOS wakes the app now and then to look for new screenshots (full Photos access only).
        .backgroundTask(.appRefresh(NewScreenshots.taskIdentifier)) {
            NewScreenshots.scheduleBackgroundCheck()
            await services.backgroundCheck()
        }
    }

    /// Makes the bundled fonts (DSEG14 for Retro Analog, SIL Open Font License) available by name.
    private static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
