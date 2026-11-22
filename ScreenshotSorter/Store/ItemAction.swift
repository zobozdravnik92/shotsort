import Foundation

/// A next step Boost suggests for an item: a reminder, a calendar event, a message to send, or a link to open.
/// Suggested by a model from screenshot text, so everything is checked before it's kept.
struct ItemAction: Codable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        /// Remind on `date` (a deadline, a return window, a follow-up).
        case reminder
        /// Add an event on `date` to the calendar.
        case calendar
        /// A short message or note; the text is in `detail`.
        case draft
        /// A link worth opening; the address is in `detail`.
        case open
    }

    var kind: Kind
    /// Short, shown on the button.
    var title: String
    /// "2026-11-30", for reminders and calendar events.
    var date: String?
    /// The draft's text, or the link's address.
    var detail: String?

    var id: String { "\(kind.rawValue)|\(title)|\(date ?? "")" }

    static let maxCount = 3
    static let maxTitleLength = 60
    static let maxDetailLength = 600

    /// The date as a day in the user's calendar, or nil if it isn't a valid yyyy-MM-dd.
    var day: Date? { date.flatMap(Self.day(from:)) }

    static func day(from text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        let calendar = Calendar.current
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == parts[2] else { return nil }  // Rejects 31 February.
        return date
    }

    /// Keeps only actions that make sense and can't mislead: a valid date where one is needed,
    /// links only to websites that appear in the screenshot, short text, at most three.
    static func cleaned(_ actions: [ItemAction], ocrText: String) -> [ItemAction] {
        var kept: [ItemAction] = []
        for var action in actions {
            action.title = action.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !action.title.isEmpty else { continue }
            action.title = Extraction.truncate(action.title, to: maxTitleLength)
            let detail = action.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            action.detail = detail.isEmpty ? nil : Extraction.truncate(detail, to: maxDetailLength)
            if let date = action.date, day(from: date) == nil { action.date = nil }

            switch action.kind {
            case .reminder, .calendar:
                guard action.date != nil else { continue }
                action.detail = nil
            case .draft:
                guard action.detail != nil else { continue }
                action.date = nil
            case .open:
                // Same rule as an item's link: the website must appear in the screenshot.
                guard let link = action.detail, let host = Extraction.webHost(of: link),
                      ocrText.lowercased().contains(host) else { continue }
                action.date = nil
            }
            if !kept.contains(action) { kept.append(action) }
            if kept.count == maxCount { break }
        }
        return kept
    }
}
