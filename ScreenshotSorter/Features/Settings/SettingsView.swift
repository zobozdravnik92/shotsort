import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var unsureCount = 0
    @State private var isImproving = false
    @State private var improveMessage: String?
    @State private var showPlans = false
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var boost = services.boost
        let connectedKinds = boost.availableKinds.filter { boost.connected.contains($0) }

        NavigationStack {
            List {
                AppearanceSection()

                NewScreenshotsSection()

                Section {
                    // Locked until there's a paid plan or the user's own key; then it's a switch.
                    if boost.connected.isEmpty && services.plans.isFree {
                        Button {
                            showPlans = true
                        } label: {
                            Label {
                                Text("Upgrade to Unlock")
                            } icon: {
                                Image(systemName: "flame.fill").foregroundStyle(.orange)
                            }
                            .font(.body.weight(.semibold))
                            // The skin's own button colours, like the wide buttons elsewhere.
                            .foregroundStyle(theme.buttonInk ?? .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(theme.buttonFill ?? theme.accent, in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(PressableCardStyle())
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    } else {
                        Toggle("Boost with a cloud model", isOn: $boost.isEnabled)
                            .disabled(boost.connected.isEmpty)
                    }
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
                         ? "Get Boost with a plan, or connect your own API key below. Until then, sorting stays on this iPhone."
                         : "With Boost on, only the text of screenshots this iPhone isn't sure about is sent to the model you choose. Images never leave your phone. Usage is billed to your own account.")
                }

                Section {
                    ForEach(boost.availableKinds) { kind in
                        NavigationLink {
                            BoostProviderView(kind: kind)
                        } label: {
                            LabeledContent(kind == .chatGPT ? "Sign in with ChatGPT" : "\(kind.name) API key") {
                                Text(boost.connected.contains(kind) ? "Connected" : "Not set")
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect")
                        Text("Unlock Boost by entering your own API key")
                            .font(.footnote)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
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
            .sheet(isPresented: $showPlans) { PlansSheet() }
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
