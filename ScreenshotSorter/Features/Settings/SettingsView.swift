import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var unsureCount = 0
    @State private var isImproving = false
    @State private var improveMessage: String?

    var body: some View {
        @Bindable var boost = services.boost
        let connectedKinds = boost.availableKinds.filter { boost.connected.contains($0) }

        NavigationStack {
            List {
                AppearanceSection()

                NewScreenshotsSection()

                Section {
                    Toggle("Boost with a cloud model", isOn: $boost.isEnabled)
                        .disabled(boost.connected.isEmpty)
                    if connectedKinds.count > 1 {
                        Picker("Use", selection: $boost.selected) {
                            ForEach(connectedKinds) { kind in
                                Text(kind.name).tag(Optional(kind))
                            }
                        }
                    }
                } header: {
                    Text("Boost")
                } footer: {
                    Text(boost.connected.isEmpty
                         ? "Connect a model below to turn on Boost. Sorting stays on this iPhone until you do."
                         : "With Boost on, only the text of screenshots this iPhone isn't sure about is sent to the model you choose. Images never leave your phone. Usage is billed to your own account.")
                }

                Section("Connect") {
                    ForEach(boost.availableKinds) { kind in
                        NavigationLink {
                            BoostProviderView(kind: kind)
                        } label: {
                            LabeledContent(kind == .chatGPT ? "Sign in with ChatGPT" : "\(kind.name) API key") {
                                Text(boost.connected.contains(kind) ? "Connected" : "Not set")
                            }
                        }
                    }
                }

                if boost.isActive {
                    Section {
                        Button {
                            Task { await improve() }
                        } label: {
                            HStack {
                                Label(unsureCount == 1 ? "Improve 1 unsure item" : "Improve \(unsureCount) unsure items", systemImage: "sparkles")
                                if isImproving {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(unsureCount == 0 || isImproving)
                        if let improveMessage {
                            Text(improveMessage).font(.footnote).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Re-sorts items this iPhone wasn't sure about, using the text already read from them. New screenshots are boosted automatically.")
                    }
                }

                if let error = boost.lastError {
                    Section("Last problem") {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                        if let date = boost.lastErrorAt {
                            Text(date, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Clear") { boost.clearError() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { ThemedBackground() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: boost.isEnabled) { _, enabled in
                if enabled && boost.selected == nil { boost.selected = connectedKinds.first }
                unsureCount = services.unsureItemCount()
            }
            .task { unsureCount = services.unsureItemCount() }
        }
    }

    private func improve() async {
        isImproving = true
        improveMessage = nil
        let improved = await services.improveUnsureItems()
        isImproving = false
        unsureCount = services.unsureItemCount()
        improveMessage = improved == 1 ? "Improved 1 item." : "Improved \(improved) items."
    }
}

#Preview {
    SettingsView()
        .environment(AppServices.preview)
        .modelContainer(AppServices.preview.container)
}
