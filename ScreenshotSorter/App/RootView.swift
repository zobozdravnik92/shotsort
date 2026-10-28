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
                }
            }
        }
        .task {
            services.prepare()
            if hasOnboarded { services.startIngest() }
        }
        // New screenshots are processed each time the app comes to the front.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && hasOnboarded { services.startIngest() }
        }
    }
}

#Preview {
    RootView()
        .environment(AppServices.preview)
        .modelContainer(AppServices.preview.container)
}
