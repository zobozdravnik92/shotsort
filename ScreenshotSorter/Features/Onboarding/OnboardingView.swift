import Photos
import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var status = PhotoAccess.status
    @State private var isRequesting = false

    private var isBlocked: Bool { status == .denied || status == .restricted }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Your screenshots, finally useful")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("The app reads your screenshots and turns them into sorted, summarised items you can clear in minutes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 20) {
                Label("Only your screenshots are read, never your other photos.", systemImage: "camera.viewfinder")
                Label("Nothing leaves your phone. Sorting happens on this iPhone, unless you turn on Boost.", systemImage: "lock.shield")
                Label("You confirm every delete, and iOS keeps deleted screenshots for 30 days.", systemImage: "arrow.uturn.backward.circle")
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            if isBlocked {
                VStack(spacing: 12) {
                    Text("Photos access is off. Turn it on in Settings to sort your screenshots.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Text("Open Settings").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                Button {
                    Task { await requestAccess() }
                } label: {
                    Text("Allow Photos access").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isRequesting)
            }

            #if DEBUG
            Button("Skip (debug)", action: onFinish)
                .font(.footnote)
            #endif
        }
        .padding(24)
    }

    private func requestAccess() async {
        isRequesting = true
        status = await PhotoAccess.request()
        isRequesting = false
        // Full and limited access both work: limited just means fewer screenshots.
        if status == .authorized || status == .limited { onFinish() }
    }
}

#Preview {
    OnboardingView {}
}
