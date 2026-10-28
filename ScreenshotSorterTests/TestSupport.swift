import Foundation
import SwiftData
@testable import ScreenshotSorter

@MainActor
func makeTestContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: Item.self, Screenshot.self, Stats.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    // Keep the container alive for the test's lifetime.
    TestContainers.all.append(container)
    return container.mainContext
}

@MainActor
enum TestContainers {
    static var all: [ModelContainer] = []
}

func makeCapture(
    _ assetID: String,
    hash: String = "abc123",
    text: String = "Senior designer at Acme in Berlin full time",
    fileSize: Int = 1_000_000,
    createdAt: Date = .now
) -> Capture {
    Capture(assetID: assetID, createdAt: createdAt, ocrText: text, imageHash: hash, fileSize: fileSize)
}

let sampleExtraction = Extraction(category: .jobs, title: "Senior designer", summary: "", fields: [:], url: nil, confidence: 0.9)

/// Records what it was asked to delete and answers like the iOS confirmation would.
actor FakeDeleter: AssetDeleting {
    let confirms: Bool
    private(set) var calls: [[String]] = []

    init(confirms: Bool) {
        self.confirms = confirms
    }

    func delete(_ assetIDs: [String]) async -> Bool {
        calls.append(assetIDs)
        return confirms
    }
}
