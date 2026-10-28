import SwiftData
import SwiftUI

@main
struct ScreenshotSorterApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
        }
        .modelContainer(services.container)
    }
}
