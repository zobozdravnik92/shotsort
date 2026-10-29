import Foundation
import StoreKitTest
import Testing
@testable import ScreenshotSorter

/// Uses Skins.storekit, so no real App Store or money is involved.
@MainActor
@Suite(.serialized)
struct SkinStoreTests {
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Skins")
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func makeStore(_ defaults: UserDefaults? = nil) -> SkinStore {
        SkinStore(defaults: defaults ?? UserDefaults(suiteName: "skin-tests-\(UUID().uuidString)")!)
    }

    /// StoreKit delivers purchases and refunds a moment after they happen, so poll briefly.
    private func waitFor(_ store: SkinStore, _ condition: () -> Bool) async throws {
        for _ in 0..<40 {
            await store.refreshEntitlements()
            if condition() { return }
            try await Task.sleep(for: .milliseconds(150))
        }
    }

    @Test func retroAnalogCostsOneDollar() async throws {
        _ = try makeSession()
        let store = makeStore()
        await store.loadProducts()
        #expect(store.products.count == 1)
        #expect(store.products[.retroAnalog]?.price == 1)
    }

    @Test func sunshineIsFreeAndTheDefault() async throws {
        _ = try makeSession()
        let store = makeStore()
        await store.refreshEntitlements()
        #expect(store.selected == .sunshine)
        #expect(store.isUnlocked(.sunshine))
        #expect(!store.isUnlocked(.retroAnalog))
    }

    @Test func lockedSkinCantBeSelected() async throws {
        _ = try makeSession()
        let store = makeStore()
        await store.refreshEntitlements()
        store.select(.retroAnalog)
        #expect(store.selected == .sunshine)
    }

    @Test func removedSkinsFallBackToSunshine() {
        let defaults = UserDefaults(suiteName: "skin-tests-\(UUID().uuidString)")!
        defaults.set("night", forKey: "skin.selected")
        #expect(makeStore(defaults).selected == .sunshine)
    }

    @Test func buyingUnlocksAndRefundFallsBackToSunshine() async throws {
        let session = try makeSession()
        let store = makeStore()

        _ = try await session.buyProduct(identifier: Skin.retroAnalog.productID!)
        try await waitFor(store) { store.isUnlocked(.retroAnalog) }
        #expect(store.isUnlocked(.retroAnalog))
        store.select(.retroAnalog)
        #expect(store.selected == .retroAnalog)

        // The transaction returned by buyProduct can carry a placeholder ID, so refund by the session's record.
        let bought = try #require(session.allTransactions().last { $0.productIdentifier == Skin.retroAnalog.productID })
        try session.refundTransaction(identifier: bought.identifier)
        try await waitFor(store) { !store.isUnlocked(.retroAnalog) }
        #expect(!store.isUnlocked(.retroAnalog))
        #expect(store.selected == .sunshine)
    }

    @Test func selectionIsRemembered() async throws {
        let defaults = UserDefaults(suiteName: "skin-tests-\(UUID().uuidString)")!
        let session = try makeSession()
        _ = try await session.buyProduct(identifier: Skin.retroAnalog.productID!)

        let first = makeStore(defaults)
        try await waitFor(first) { first.isUnlocked(.retroAnalog) }
        first.select(.retroAnalog)

        #expect(makeStore(defaults).selected == .retroAnalog)
    }
}
