import SwiftUI

/// Onboarding until Photos access is granted, then Home.
struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        Group {
            if hasOnboarded {
                NavigationStack {
                    HomeView()
                }
            } else {
                OnboardingView {
                    hasOnboarded = true
                    services.startIngest()
                    services.watchLibrary()
                    // With full access the app can tell you about new screenshots, so ask once.
                    if PhotoAccess.isFull {
                        Task { _ = await NewScreenshots.requestNotificationPermission() }
                    }
                }
            }
        }
        // The chosen skin applies everywhere: colours, accent, and light or dark.
        .environment(\.theme, services.skins.theme)
        .tint(services.skins.theme.accent)
        .preferredColorScheme(services.skins.selected.colorScheme)
        .task {
            guard !AppServices.isHostingTests else { return }
            await services.skins.start()
        }
        .task {
            guard !AppServices.isHostingTests else { return }
            services.prepare()
            if hasOnboarded {
                services.startIngest()
                services.watchLibrary()
            }
        }
        // New screenshots are processed each time the app comes to the front,
        // and a background check is booked when it leaves.
        .onChange(of: scenePhase) { _, phase in
            guard hasOnboarded, !AppServices.isHostingTests else { return }
            switch phase {
            case .active: services.startIngest()
            case .background: if PhotoAccess.isFull { NewScreenshots.scheduleBackgroundCheck() }
            default: break
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppServices.preview)
        .modelContainer(AppServices.preview.container)
}
