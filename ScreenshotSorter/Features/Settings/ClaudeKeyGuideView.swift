import SwiftUI

/// The guided Claude key setup from the spec: most people have never made an API key.
struct ClaudeKeyGuideView: View {
    private struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
        var link: URL?
    }

    private let steps: [Step] = [
        Step(id: 1, title: "Open the Claude Console", detail: "Sign in, or create an account.", link: URL(string: "https://platform.claude.com/")),
        Step(id: 2, title: "Add credits", detail: "API use is billed per use to your Console account, separate from any Claude subscription."),
        Step(id: 3, title: "Go to API keys", detail: "Open the API keys page in Settings.", link: URL(string: "https://platform.claude.com/settings/keys")),
        Step(id: 4, title: "Create a key", detail: "Tap Create key and name it, for example \"Screenshots\"."),
        Step(id: 5, title: "Copy the key", detail: "It starts with sk-ant- and is shown only once. If you lose it, make a new one."),
        Step(id: 6, title: "Paste it here", detail: "Come back, tap Paste on the previous screen, then Test and save."),
    ]

    var body: some View {
        List {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(step.id)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.tint, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title).font(.headline)
                        Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                        if let link = step.link {
                            Link("Open in Safari", destination: link).font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Get a Claude key")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ClaudeKeyGuideView()
    }
}
