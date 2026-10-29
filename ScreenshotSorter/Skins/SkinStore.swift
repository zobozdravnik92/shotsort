import Foundation
import Observation
import StoreKit

/// Which skins the user owns and which one is in use. Paid skins are one-time ($1) purchases through StoreKit 2.
@MainActor
@Observable
final class SkinStore {
    private(set) var products: [Skin: Product] = [:]
    private(set) var owned: Set<Skin> = []
    /// Shown under the skin list in Settings.
    var message: String?

    var selected: Skin {
        didSet { defaults.set(selected.rawValue, forKey: Self.selectedKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updates: Task<Void, Never>?
    private static let selectedKey = "skin.selected"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selected = defaults.string(forKey: Self.selectedKey).flatMap(Skin.init(rawValue:)) ?? .sunshine
    }

    var theme: Theme { selected.theme }

    /// Debug builds unlock every skin, so paid ones can be tried without the App Store.
    var unlocksAllSkins = false

    func isUnlocked(_ skin: Skin) -> Bool { skin.isFree || unlocksAllSkins || owned.contains(skin) }

    /// Loads prices and purchases, and listens for purchases made elsewhere (other devices, Ask to Buy, refunds).
    func start() async {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        let ids = Skin.allCases.compactMap(\.productID)
        guard let loaded = try? await Product.products(for: ids) else { return }
        var map: [Skin: Product] = [:]
        for product in loaded {
            if let skin = Skin.forProductID(product.id) { map[skin] = product }
        }
        products = map
    }

    /// Rebuilds the owned set from Apple's record. A refunded skin falls back to the free one.
    func refreshEntitlements() async {
        var current: Set<Skin> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil,
               let skin = Skin.forProductID(transaction.productID) {
                current.insert(skin)
            }
        }
        owned = current
        if !isUnlocked(selected) { selected = .sunshine }
    }

    func select(_ skin: Skin) {
        guard isUnlocked(skin) else { return }
        selected = skin
    }

    /// Handles the result of a purchase started from SwiftUI's `purchase` action.
    @discardableResult
    func handlePurchase(_ result: Product.PurchaseResult, for skin: Skin) async -> Bool {
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                message = "Apple couldn't verify this purchase."
                return false
            }
            owned.insert(skin)
            await transaction.finish()
            selected = skin
            message = nil
            return true
        case .pending:
            message = "The purchase is waiting for approval."
            return false
        case .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            message = "Couldn't reach the App Store. Try again later."
            return
        }
        await refreshEntitlements()
        message = owned.isEmpty ? "No skin purchases to restore." : "Purchases restored."
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await refreshEntitlements()
        await transaction.finish()
    }
}
