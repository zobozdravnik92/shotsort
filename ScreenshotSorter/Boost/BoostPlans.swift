import Foundation
import Observation
import StoreKit

/// Paid Boost tiers, sold as monthly subscriptions in one group (Superboost ranks above Boost).
/// Bring-your-own-key Boost in Settings stays free and is separate from these.
enum BoostPlan: String, CaseIterable, Comparable, Sendable {
    case free, boost, superboost

    static let paid: [BoostPlan] = [.boost, .superboost]

    var productID: String? {
        switch self {
        case .free: nil
        case .boost: "com.rokpremuz.ScreenshotSorter.boost.monthly"
        case .superboost: "com.rokpremuz.ScreenshotSorter.superboost.monthly"
        }
    }

    var name: String {
        switch self {
        case .free: "Free"
        case .boost: "Boost"
        case .superboost: "Superboost"
        }
    }

    var tagline: String {
        switch self {
        case .free: "Sorting on your iPhone."
        case .boost: "Smarter sorting, and next steps for what you save."
        case .superboost: "Sees your screenshots and answers your questions."
        }
    }

    /// Shown until the App Store price loads.
    var fallbackPrice: String {
        switch self {
        case .free: "Free"
        case .boost: "€1.99"
        case .superboost: "€4.99"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return ["Sorting and search on your iPhone"]
        case .boost:
            return [
                "Sorts the screenshots your iPhone isn't sure about",
                "Clearer titles, summaries and details",
                "Finds next steps: reminders, events and drafts",
                "Up to 1,000 screenshots a month",
                "Only text is sent; images stay on your iPhone",
            ]
        case .superboost:
            return [
                "Everything in Boost",
                "Reads images too, for designs, products and photos (you choose)",
                "Every screenshot, with a smarter model",
                "Ask your screenshots questions",
                "Up to 300 image Boosts a month",
                "Every skin included, Graphite too",
            ]
        }
    }

    static func forProductID(_ id: String) -> BoostPlan? {
        allCases.first { $0.productID == id }
    }

    private var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: BoostPlan, rhs: BoostPlan) -> Bool { lhs.rank < rhs.rank }
}

/// Which Boost plan the user pays for, from Apple's record of their subscriptions.
@MainActor
@Observable
final class BoostPlanStore {
    private(set) var products: [BoostPlan: Product] = [:]
    private(set) var current: BoostPlan = .free
    var message: String?

    @ObservationIgnored private var updates: Task<Void, Never>?

    var isFree: Bool { current == .free }

    func start() async {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
        await loadProducts()
        await refresh()
    }

    func loadProducts() async {
        let ids = BoostPlan.paid.compactMap(\.productID)
        guard let loaded = try? await Product.products(for: ids) else { return }
        var map: [BoostPlan: Product] = [:]
        for product in loaded {
            if let plan = BoostPlan.forProductID(product.id) { map[plan] = product }
        }
        products = map
    }

    /// The highest active plan. Expired, refunded or revoked subscriptions don't count.
    func refresh() async {
        var best = BoostPlan.free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > .now }) ?? true,
                  let plan = BoostPlan.forProductID(transaction.productID) else { continue }
            best = max(best, plan)
        }
        current = best
    }

    /// Handles the result of SwiftUI's `purchase` action. Returns true when the plan is now active.
    @discardableResult
    func handlePurchase(_ result: Product.PurchaseResult) async -> Bool {
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                message = "The App Store couldn't confirm this purchase."
                return false
            }
            await transaction.finish()
            await refresh()
            message = nil
            return true
        case .pending:
            message = "Waiting for approval. Your plan starts once the purchase is approved."
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
            await refresh()
            message = isFree ? "No active Boost plan was found for this Apple Account." : nil
        } catch {
            message = "Couldn't reach the App Store. Try again in a moment."
        }
    }
}
