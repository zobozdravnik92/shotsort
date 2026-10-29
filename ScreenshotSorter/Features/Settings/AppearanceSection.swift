import StoreKit
import SwiftUI

/// Pick a skin, or buy one for $1.
struct AppearanceSection: View {
    @Environment(AppServices.self) private var services
    @Environment(\.purchase) private var purchase
    @State private var buying: Skin?

    private var store: SkinStore { services.skins }

    var body: some View {
        Section {
            ForEach(Skin.allCases) { skin in
                Button {
                    Task { await choose(skin) }
                } label: {
                    row(skin)
                }
                // Plain keeps the names black instead of tinted like links.
                .buttonStyle(.plain)
                .disabled(buying != nil)
            }
            Button("Restore purchases") {
                Task { await store.restore() }
            }
            if let message = store.message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Skins are one-time purchases and work on every device with the same Apple ID.")
        }
    }

    private func row(_ skin: Skin) -> some View {
        HStack(spacing: 14) {
            SkinSwatch(theme: skin.theme)
            VStack(alignment: .leading, spacing: 2) {
                Text(skin.name).foregroundStyle(.primary)
                Text(skin.isFree ? "Bright and bold" : "Radio-dial greens and LCD type")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing(skin)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(store.selected == skin ? .isSelected : [])
    }

    @ViewBuilder
    private func trailing(_ skin: Skin) -> some View {
        if store.selected == skin {
            Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint)
        } else if store.isUnlocked(skin) {
            Text(skin.isFree ? "Free" : (store.owned.contains(skin) ? "Owned" : "Unlocked in debug"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if buying == skin {
            ProgressView()
        } else if let product = store.products[skin] {
            Text(product.displayPrice)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.tint.opacity(0.15), in: Capsule())
                .foregroundStyle(.tint)
        } else {
            Text("Unavailable").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func choose(_ skin: Skin) async {
        if store.isUnlocked(skin) {
            withAnimation { store.select(skin) }
            return
        }
        guard let product = store.products[skin] else {
            store.message = "Skins can't be bought right now. Check your connection and try again."
            return
        }
        buying = skin
        defer { buying = nil }
        do {
            let result = try await purchase(product)
            await store.handlePurchase(result, for: skin)
        } catch {
            store.message = "The purchase didn't go through. You weren't charged."
        }
    }
}

/// A small preview of a skin: its background with three card colours.
struct SkinSwatch: View {
    let theme: Theme

    var body: some View {
        HStack(spacing: -6) {
            ForEach(Array(theme.swatch.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(theme.cardOutline ?? .clear, lineWidth: 1.5))
            }
        }
        .frame(width: 52, height: 36)
        .background(theme.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

#Preview {
    List { AppearanceSection() }
        .environment(AppServices.preview)
}
