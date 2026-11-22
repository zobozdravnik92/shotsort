import SwiftUI

/// Small pill in the triage bar: whether Boost is on, and how many screenshots it sorted this month.
struct BoostBadge: View {
    let action: () -> Void

    @Environment(AppServices.self) private var services
    @Environment(\.theme) private var theme

    var body: some View {
        let boost = services.boost
        let count = boost.usage.boosted(inMonthOf: .now)

        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: boost.isActive ? "flame.fill" : "flame")
                    .font(.system(size: 12, weight: .bold))
                Text(boost.isActive ? "\(count)" : theme.text("Off"))
                    .font(.system(size: 15, weight: .bold, design: theme.fontDesign).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .lineLimit(1)
            .foregroundStyle(.white)
            .opacity(boost.isActive ? 1 : 0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(theme.background.mix(with: .black, by: 0.18), in: Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: count)
        .accessibilityLabel(boost.isActive ? "Boost on, \(count) used this month" : "Boost off")
        .accessibilityHint("Shows Boost details.")
    }
}

/// Details behind the Boost badge: status, model, usage this month, and how Boost works.
struct BoostUsageSheet: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false

    var body: some View {
        @Bindable var boost = services.boost
        let usage = boost.usage
        let kind = boost.selected

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.orange)
                            Text("\(usage.boosted(inMonthOf: .now))")
                                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                                .contentTransition(.numericText())
                        }
                        Text("screenshots sorted with Boost this month")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)

                    LabeledContent("Last month", value: "\(usage.boostedLastMonth())")
                    LabeledContent("All time", value: "\(usage.boostedAllTime)")
                    let failed = usage.failed(inMonthOf: .now)
                    if failed > 0 {
                        LabeledContent("Couldn't reach the model", value: failed == 1 ? "1 time" : "\(failed) times")
                    }
                }

                Section {
                    Toggle("Use Boost", isOn: $boost.isEnabled)
                        .disabled(boost.connected.isEmpty)
                    if let kind, boost.connected.contains(kind) {
                        LabeledContent("Model", value: modelName(kind))
                    }
                    if let error = boost.lastError, let date = boost.lastErrorAt {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(date, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Boost settings") { showSettings = true }
                } footer: {
                    Text(footer(kind: kind))
                }
            }
            .navigationTitle("Boost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func modelName(_ kind: CloudProviderKind) -> String {
        guard let model = services.boost.model(for: kind) else { return kind.name }
        return "\(kind.name) · \(model)"
    }

    private func footer(kind: CloudProviderKind?) -> String {
        if services.boost.connected.isEmpty {
            return "Connect a cloud model in Boost settings to sort the screenshots this iPhone isn't sure about. Until then, everything is sorted on this iPhone."
        }
        let billing = kind == .chatGPT ? "Usage counts toward your ChatGPT plan." : "Usage is billed to your own \(kind?.name ?? "model") account."
        return "Only screenshots this iPhone isn't sure about are sent, as text. Images never leave your phone. \(billing)"
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        BoostUsageSheet()
    }
    .environment(AppServices.preview)
}
