import Foundation
import SwiftData

/// Sample items for SwiftUI previews.
@MainActor
enum SampleData {
    private struct Sample {
        let category: ItemCategory
        let title: String
        let summary: String
        let fields: [String: String]
        var status: ItemStatus = .new
        var url: String?
    }

    private static let samples: [Sample] = [
        Sample(category: .jobs, title: "Senior Product Designer", summary: "Design systems role on the payments team. Five years of experience, Figma and prototyping.", fields: ["company": "Acme Pay", "location": "Berlin", "remote": "hybrid", "salary": "€85–100k", "seniority": "Senior"], url: "acme.example/jobs/42"),
        Sample(category: .jobs, title: "Staff Designer, Growth", summary: "Owns onboarding and activation experiments across web and mobile.", fields: ["company": "Northwind", "remote": "yes", "seniority": "Staff"]),
        Sample(category: .posts, title: "Portfolio reviews should start with the problem", summary: "Lead with the problem and your role before showing screens.", fields: ["author": "Jamie Rivera", "platform": "LinkedIn", "topic": "Portfolios"]),
        Sample(category: .people, title: "Priya Shah", summary: "Design manager hiring for a fintech team; worth a coffee chat.", fields: ["title": "Design Manager", "company": "Ledgerly", "whySaved": "Hiring designers"], status: .kept),
        Sample(category: .inspiration, title: "Calm paywall with a single plan", summary: "Pricing screen with one plan, a short benefit list and a soft gradient.", fields: ["source": "Headway", "element": "pricing", "style": "minimal"]),
        Sample(category: .shopping, title: "Merino crew neck jumper", summary: "Navy, size M, in stock with free delivery.", fields: ["price": "€89", "store": "Arket"]),
        Sample(category: .receipts, title: "Train ticket, Ljubljana to Zagreb", summary: "Single ticket for 14 Nov.", fields: ["amount": "€19.40", "date": "14 Nov"]),
        Sample(category: .other, title: "Meme about Monday meetings", summary: "A cat asleep on a laptop keyboard.", fields: [:]),
    ]

    static func insert(into context: ModelContext) {
        for (index, sample) in samples.enumerated() {
            let date = Date.now.addingTimeInterval(Double(-index) * 3_600)
            let item = Item(
                category: sample.category,
                title: sample.title,
                summary: sample.summary,
                fields: sample.fields,
                url: sample.url,
                status: sample.status,
                processedBy: "apple-on-device",
                savedAt: date,
                confidence: 0.9
            )
            context.insert(item)
            let screenshot = Screenshot(assetID: "preview-\(index)", createdAt: date, ocrText: sample.summary, imageHash: "", fileSize: 2_400_000, processedAt: .now)
            context.insert(screenshot)
            item.screenshots.append(screenshot)
        }
        try? context.save()
    }

    static func firstItem(in context: ModelContext) -> Item {
        if let item = try? context.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])).first {
            return item
        }
        return Item(category: .other, title: "Sample", summary: "", processedBy: "fallback", savedAt: .now)
    }
}
