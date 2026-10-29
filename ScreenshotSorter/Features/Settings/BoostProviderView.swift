import AuthenticationServices
import SwiftUI

/// Connect one cloud provider: paste and test an API key, or sign in with ChatGPT.
struct BoostProviderView: View {
    let kind: CloudProviderKind

    @Environment(AppServices.self) private var services
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var key = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var boost: BoostSettings { services.boost }
    private var isConnected: Bool { boost.connected.contains(kind) }

    var body: some View {
        List {
            if isConnected {
                connectedSection
            } else if kind == .chatGPT {
                signInSection
            } else {
                keyEntrySection
            }

            Section {
                Text(billingNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if kind == .claude && !isConnected {
                Section {
                    NavigationLink("How to get a Claude key") { ClaudeKeyGuideView() }
                }
            } else if let url = kind.keysURL, !isConnected {
                Section {
                    Link(destination: url) {
                        Label("Get a \(kind.name) key", systemImage: "safari")
                    }
                }
            }
        }
        .navigationTitle(kind == .chatGPT ? "ChatGPT" : "\(kind.name) API key")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var connectedSection: some View {
        Section {
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            if let masked = boost.maskedCredential(for: kind) {
                LabeledContent("Key", value: masked)
            }
            if let model = boost.model(for: kind) {
                LabeledContent("Model", value: model)
            }
            Button(kind == .chatGPT ? "Sign out" : "Remove key", role: .destructive) {
                boost.disconnect(kind)
                key = ""
            }
        } footer: {
            Text("Stored in this iPhone's Keychain. It's never shown in full again.")
        }
    }

    private var keyEntrySection: some View {
        Section {
            SecureField(kind.keyPlaceholder, text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
            // PasteButton reads the clipboard only when tapped, so iOS doesn't show a paste prompt.
            PasteButton(payloadType: String.self) { strings in
                let pasted = strings.first ?? ""
                Task { @MainActor in key = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            if let other = CloudProviderKind.detect(key: key), other != kind {
                Label("This looks like a \(other.name) key.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Button {
                Task { await testAndSave() }
            } label: {
                HStack {
                    Text("Test and save")
                    if isWorking {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        } footer: {
            Text("The app makes one free test call to check the key.")
        }
    }

    private var signInSection: some View {
        Section {
            Button {
                Task { await signInWithChatGPT() }
            } label: {
                HStack {
                    Label("Sign in with ChatGPT", systemImage: "person.crop.circle.badge.checkmark")
                    if isWorking {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isWorking || !ChatGPTConfig.isAvailable)
            if !ChatGPTConfig.isAvailable {
                Text("Not set up yet: the app needs a client ID from OpenAI. Shown in debug builds only.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        } footer: {
            Text("Needs ChatGPT Plus or Pro. You'll set a weekly limit for this app in ChatGPT.")
        }
    }

    private var billingNote: String {
        switch kind {
        case .chatGPT: "Uses your ChatGPT plan's allowance, up to the weekly limit you set for this app."
        case .openAI: "Pay per use on your OpenAI account."
        case .claude: "Pay per use on your Anthropic account, separate from any Claude subscription. Claude subscriptions can't be used by other apps."
        case .gemini: "Pay per use on your Google account. Google AI Pro and Ultra plans can't be used by other apps yet."
        }
    }

    // MARK: - Actions

    private func testAndSave() async {
        isWorking = true
        errorMessage = nil
        do {
            try await boost.connect(kind, key: key)
            key = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func signInWithChatGPT() async {
        isWorking = true
        errorMessage = nil
        do {
            let signIn = ChatGPTSignIn()
            let request = try await signIn.makeRequest()
            let callback = try await webAuthenticationSession.authenticate(
                using: request.url,
                callbackURLScheme: ChatGPTConfig.callbackScheme,
                preferredBrowserSession: .ephemeral
            )
            let tokens = try await signIn.complete(request, callback: callback)
            try await boost.connectChatGPT(tokens)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // The person closed the sign-in sheet; nothing to report.
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}

#Preview {
    NavigationStack {
        BoostProviderView(kind: .claude)
    }
    .environment(AppServices.preview)
}
