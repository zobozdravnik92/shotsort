# Screenshot Sorter — Build Spec

An iPhone app that reads the user's screenshots, turns them into structured **items** grouped by category, and makes clearing them fast and rewarding with Tinder-style triage. AI runs on-device by default.

Product plan (source of truth for product decisions): the "Screenshot Sorter — Product Plan" doc. This file is the build spec for Claude Code.

---

## 1. Principles

1. **Items, not images.** Users browse structured items (title + fields). The screenshot is one tap deeper, as the source.
2. **On-device first.** Nothing leaves the phone unless the user turns on Boost (cloud model).
3. **Triage is the heart.** Swipe right = keep, swipe left = delete. Nothing else.
4. **Reward reviewing, not just deleting.** Keeps count toward streaks too.
5. **Never lose data silently.** Undo is always available; deletes are queued and confirmed by iOS.

## 2. Platform and stack

- iOS 27, iPhone only, SwiftUI, Swift 6 concurrency.
- Persistence: SwiftData.
- Photos: PhotoKit (screenshots only, via the screenshot media subtype).
- OCR: Vision text recognition.
- AI: Foundation Models framework (on-device Apple model by default; cloud providers via the same `LanguageModel` protocol for Boost).
- Secrets: Keychain.
- **No third-party dependencies** unless approved. Anthropic's Foundation Models package for Claude is allowed in Phase 4.
- iOS 27 APIs are new: **check Apple's current documentation for exact API names and signatures before using them.** Don't guess.

## 3. Architecture

```
PhotoKit (Screenshots) → Ingest → OCR (Vision) → Understand (AIProvider) → SwiftData store → UI
                                                                          ↘ Similarity (hash + text)
```

Modules (one folder each):

| Module | Responsibility |
| --- | --- |
| `Ingest` | Fetch screenshot assets, track which are new, batch processing, progress |
| `Extract` | OCR text from an asset; perceptual hash for duplicates |
| `Understand` | `AIProvider` protocol + implementations; returns structured `Extraction` |
| `Store` | SwiftData models and queries |
| `Triage` | Swipe deck, delete queue, undo, commit |
| `Rewards` | Counters, milestones, stats |
| `Features` (UI) | Home, Category list, Item detail, Search, Triage, Settings, Onboarding |

### AIProvider

```swift
protocol AIProvider {
    var id: String { get }              // "apple-on-device", "claude", "openai"
    var isAvailable: Bool { get async }
    func extract(text: String, image: CGImage?) async throws -> Extraction
}
```

- `AppleOnDeviceProvider` — default. Check model availability at launch; if unavailable, show a clear notice and use `FallbackProvider`.
- `FallbackProvider` — no LLM: keyword rules on OCR text to pick a category and a title (first meaningful line). Used on unsupported devices and in tests.
- Cloud providers (Phase 4) send **OCR text only**, never images, unless the user opts in.

### Extraction (structured output)

Use guided generation (generable structs) so the model returns typed data, not free text.

```swift
struct Extraction {
    var category: Category
    var title: String          // ≤ 60 chars
    var summary: String        // 1–2 sentences
    var fields: [String: String]   // category-specific, see §5
    var url: String?           // if one is visible
    var confidence: Double     // 0–1, self-reported; < 0.5 → candidate for Boost later
}
```

## 4. Data model (SwiftData)

```swift
@Model class Screenshot {
    var assetID: String            // PHAsset localIdentifier, unique
    var createdAt: Date
    var ocrText: String
    var imageHash: String          // perceptual hash for exact-duplicate detection
    var fileSize: Int              // bytes, for "space freed"
    var processedAt: Date?
    var item: Item?
}

@Model class Item {
    var id: UUID
    var category: Category
    var title: String
    var summary: String
    var fields: [String: String]
    var url: String?
    var screenshots: [Screenshot]  // one item can span several screenshots
    var status: ItemStatus         // .new, .kept, .queuedForDelete, .deleted
    var reviewedAt: Date?
    var processedBy: String        // provider id, shown in detail view
}

@Model class Stats {
    var totalReviewed: Int
    var totalDeleted: Int
    var bytesFreed: Int
    var bestStreak: Int
    var achievements: [String]
}
```

## 5. Categories and fields

| Category | Title | Fields |
| --- | --- | --- |
| `jobs` | Role | company, location, remote (yes/no/hybrid), salary, seniority |
| `posts` | The idea in one line | author, platform, topic |
| `people` | Name | title, company, whySaved |
| `inspiration` | What it shows | source, element (onboarding, pricing, nav…), style |
| `shopping` | Product | price, store |
| `receipts` | Merchant or document | amount, date |
| `conversations` | Who and about what | app |
| `other` | Short description | — |

Fields are optional. Missing → omitted, never "N/A".

## 6. Screens

1. **Onboarding** — why Photos access is needed, "nothing leaves your phone", grant access (support limited access).
2. **Home** — category cards (icon, name, item count, unreviewed count), "N new since last time", backlog progress ring, big **Start triage** button. First run: processing progress, cards appear as items are created.
3. **Category list** — item rows: title + 2–3 key fields as chips + date. Sort (newest, title) and simple filters (e.g. remote only for jobs). Select mode for bulk actions.
4. **Item detail** — title, summary, all fields, "Open link" if `url`, thumbnails of source screenshots (tap → full screen), "Processed on device / in the cloud" label, actions: keep, delete, move category.
5. **Search** — one field, searches title, summary, fields and OCR text. (Phase 3: semantic search.)
6. **Triage** — see §7.
7. **Settings** — Boost (Phase 4), sounds toggle, stats, reset.

## 7. Triage

- Full-screen card deck of `.new` items (all, or one category).
- Card shows category, title, key fields, summary; tap card → full screenshot.
- **Swipe right = keep** (`.kept`), **swipe left = delete** (`.queuedForDelete`). Card follows the finger, rotates slightly, flies off with weight. Green/red tint by direction.
- Undo button always visible: restores the last card.
- Top bar: live counters — reviewed, deleted, MB freed (pending).
- Deletes are **queued**. On "Done" (or leaving triage), show one summary and call PhotoKit delete for all queued assets in one request → iOS shows one system confirmation.
  - Confirmed → items `.deleted`, stats updated.
  - Cancelled → items go back to `.new`; counters revert. Never show fake progress.
- Haptics: light for keep, medium for delete, success pattern on milestones.

## 8. Rewards (Phase 1 minimal, Phase 3 full)

Phase 1:
- Live counters in triage.
- Streak toasts at 10, 25, 50, 100, 250 consecutive swipes (keep or delete both count).
- Space toasts at 100 MB, 500 MB, 1 GB freed (after commit).
- Category "all clear" moment when unreviewed hits 0.
- Session summary sheet: reviewed, deleted, MB freed.

Copy examples: "10 down. You're on a roll." · "50 in a row. Your camera roll thanks you." · "Freed 100 MB." · "Jobs: all clear."

Phase 3: lifetime stats, achievements (First 100, Gigabyte Club, Inbox Zero, Speed Run), personal bests, shareable summary card, rediscovery. Celebrations tone down after first few occurrences.

## 9. Similarity

- **Exact duplicates:** same perceptual hash → same item, extra screenshots attached.
- **Same item across screens:** screenshots taken within 2 minutes of each other with strong text overlap and the same category → merge into one item.
- **Never bulk-delete by topic.** "Remove similar" only offers duplicates and merged screens, with a review step.

## 10. Processing

- First run: process newest first in batches of ~20; UI updates as items are created.
- Later launches: process only screenshots not yet in the store.
- Keep processing off the main actor; the UI must stay smooth during triage.
- Remember `processedAt`; never re-run the model on processed screenshots unless the user asks.

## 11. Privacy

- Request only what's needed; screenshots only.
- No analytics, no network calls in Phases 1–3.
- Boost (Phase 4) is off by default, sends OCR text only, and labels items processed in the cloud.
- API keys in Keychain, never logged, never shown in full after saving.

## 12. Phases and acceptance criteria

### Phase 1 — Thin slice (build this first)
- [ ] Onboarding + Photos permission (full and limited).
- [ ] Ingest screenshots, OCR, extract with `AppleOnDeviceProvider` (fallback if unavailable).
- [ ] Items stored in SwiftData; duplicates merged by hash.
- [ ] Home with category cards and counts; Category list; Item detail.
- [ ] Triage with swipe, undo, queued delete, single iOS confirmation.
- [ ] Phase 1 rewards (§8).
- [ ] A debug menu (debug builds only): reprocess all, wipe store, import sample images from Files for testing in the Simulator.
- **Done when:** on a real iPhone with a few hundred screenshots, first items appear within ~1 minute, triage of 50 items feels instant, and deletes free real space.

### Phase 2 — Organising
- [ ] Bulk actions in Category list: delete screenshots, keep item + delete screenshot, mark reviewed, move category, merge.
- [ ] One export per category: jobs → CSV, posts → share to Notes as text list, others → text list via share sheet.
- [ ] "Open link" and source detection.
- [ ] "N new since last time" on Home.

### Phase 3 — Delight
- [ ] Full rewards (§8 Phase 3).
- [ ] Semantic search.
- [ ] Freshness flags (jobs older than ~4 weeks), privacy sweep (codes, banking, boarding passes).

### Phase 4 — Boost (cloud)
- [ ] Settings → Boost: Claude API key, OpenAI API key, Gemini API key (from Google AI Studio). Sign in with ChatGPT later, after partner approval. Google AI subscriptions can't be used by third-party apps yet.
- [ ] Guided Claude key setup: 6 steps (app → platform.claude.com → add credits → API keys → Create key → copy `sk-ant-…` → paste and test). Detect a copied `sk-ant-` key on return.
- [ ] Route only low-confidence items (< 0.5) and explicit "Ask" queries to the cloud.
- [ ] Silent fallback to on-device on errors; status shown in Settings.

## 13. Working rules for Claude Code

- Work phase by phase. Before each phase, list the files you'll create and wait for a go.
- Build after every meaningful change; fix all warnings.
- Small, readable SwiftUI views; previews for every screen with sample data.
- Verify every iOS 27 API (Foundation Models, Vision, PhotoKit changes) against current Apple docs before using it.
- Don't add dependencies without asking.
- Unit tests for: category fallback rules, duplicate merging, delete-queue commit/cancel, milestone triggers.
- Design: clean, native iOS look; SF Symbols; one accent colour; generous spacing. Polish comes after Phase 1 works.
