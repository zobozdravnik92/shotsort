import Foundation
import Testing
@testable import ScreenshotSorter

struct KeychainStoreTests {
    /// A separate service per test so nothing touches real keys.
    private let store = KeychainStore(service: "com.rokpremuz.ScreenshotSorter.tests.\(UUID().uuidString)")

    @Test func savesReadsAndDeletes() throws {
        #expect(store.read("key") == nil)
        try store.save("sk-ant-test-1", for: "key")
        #expect(store.read("key") == "sk-ant-test-1")
        store.delete("key")
        #expect(store.read("key") == nil)
    }

    @Test func savingAgainReplacesTheValue() throws {
        try store.save("first", for: "key")
        try store.save("second", for: "key")
        #expect(store.read("key") == "second")
        store.delete("key")
    }

    @Test func chatGPTTokensRoundTrip() throws {
        let tokens = ChatGPTTokens(accessToken: "access", refreshToken: "refresh", expiresAt: Date(timeIntervalSince1970: 2_000_000_000))
        ChatGPTTokenStore.save(tokens, to: store)
        #expect(ChatGPTTokenStore.load(from: store) == tokens)
        store.delete(CloudProviderKind.chatGPT.keychainAccount)
    }

    @Test func pkceChallengeIsBase64URLSHA256() {
        // Expected value computed independently:
        // printf '%s' <verifier> | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '='
        let challenge = ChatGPTSignIn.challenge(for: "dBjftJeZ4CVP-mJ92K3VD1IIjVfvuGyG0HQBi_2XTJw")
        #expect(challenge == "Kvg2lHT-sfDFrYkxB-VXT3BBm8xwNGxLZhpJ4fxP26E")
        #expect(!challenge.contains("=") && !challenge.contains("+") && !challenge.contains("/"))
    }
}
