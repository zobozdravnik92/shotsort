import StoreKit
import SwiftUI

/// The "Upgrade" pill beside the Settings button, shown to free users.
struct UpgradePill: View {
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
                Text(theme.text("Upgrade"))
                    .font(.system(size: 15, weight: .bold, design: theme.fontDesign))
            }
            .foregroundStyle(theme.buttonInk ?? .white)
            .padding(.horizontal, 14)
            .frame(height: 36)
            // Shadow on the pill only, so the icon and text stay crisp.
            .background { Capsule().fill(theme.buttonFill ?? .black).themedShadow(theme) }
            .fixedSize()
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("Upgrade")
        .accessibilityHint("Shows the Boost and Superboost plans.")
    }
}

/// Boost and Superboost, each with what it adds and its own button.
struct PlansSheet: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @State private var buying: BoostPlan?
    @State private var showSettings = false

    var body: some View {
        let plans = services.plans

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Get more from your screenshots")
                            .font(.title.bold())
                        Text("Your iPhone sorts everything for free. Boost and Superboost add a cloud model on top.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(BoostPlan.paid.reversed(), id: \.self) { plan in
                        PlanCard(
                            plan: plan,
                            product: plans.products[plan],
                            isCurrent: plans.current == plan,
                            isBuying: buying == plan,
                            isBusy: buying != nil
                        ) { product in
                            Task { await buy(product, plan: plan) }
                        }
                    }

                    if let message = plans.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly subscriptions, renewed automatically until you cancel in Settings › Apple Account › Subscriptions.")
                        Button("Restore purchases") { Task { await plans.restore() } }
                        Button("Have your own API key? Use Boost with it for free") { showSettings = true }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func buy(_ product: Product, plan: BoostPlan) async {
        buying = plan
        defer { buying = nil }
        do {
            let result = try await purchase(product)
            if await services.plans.handlePurchase(result) { dismiss() }
        } catch {
            services.plans.message = "The purchase didn't go through. You weren't charged."
        }
    }
}

private struct PlanCard: View {
    let plan: BoostPlan
    let product: Product?
    let isCurrent: Bool
    let isBuying: Bool
    let isBusy: Bool
    let onBuy: (Product) -> Void

    private var accent: Color { plan == .superboost ? .orange : .primary }
    private var price: String { product?.displayPrice ?? plan.fallbackPrice }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(plan.name, systemImage: plan == .superboost ? "flame.fill" : "flame")
                    .font(.title3.bold())
                    .foregroundStyle(accent)
                if plan == .superboost {
                    tag("Best", color: .orange)
                }
                if isCurrent {
                    tag("Current", color: .green)
                }
                Spacer()
                Text("\(price)/mo")
                    .font(.headline.monospacedDigit())
            }
            Text(plan.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features, id: \.self) { feature in
                    Label {
                        Text(feature).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(accent)
                    }
                    .font(.subheadline)
                }
            }
            buyButton
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            if plan == .superboost {
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.orange, lineWidth: 2.5)
            }
        }
    }

    private var buyButton: some View {
        Button {
            if let product { onBuy(product) }
        } label: {
            Group {
                if isBuying {
                    ProgressView().tint(.white)
                } else if isCurrent {
                    Text("Your plan")
                } else if product == nil {
                    Text("Not available yet")
                } else {
                    Text("Get \(plan.name) · \(price)/month")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(plan == .superboost ? .orange : .black)
        .disabled(product == nil || isCurrent || isBusy)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2), in: Capsule())
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) { PlansSheet() }
        .environment(AppServices.preview)
}
