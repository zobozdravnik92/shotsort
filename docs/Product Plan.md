# Screenshot Sorter — Product Plan

Oct 25, 2026 · @Rok Premuz

## Problem and vision

People save screenshots to come back to later, then never do: the pile grows into hundreds and opening it feels overwhelming. The app turns that pile into a few sorted, summarised, searchable groups — processed entirely on the phone.

**One-line pitch:** Your screenshots, finally useful — sorted and summarised on your iPhone, privately.

- **Origin case:** job search. Screenshots of job posts, useful LinkedIn posts, design inspiration and people worth contacting pile up and never get reviewed.
- **Core promise:** open the app, see your screenshots as a handful of meaningful groups, get the gist without opening each one, find anything by describing it.
- **Privacy as the hook:** nothing leaves the device. Screenshots are often sensitive (messages, banking, health), so on-device processing is a selling point, not just a technical choice.
- **Ambition:** a consumer app for millions of iPhone users, not only a personal tool.

## Users and use cases

The first user is a job seeker who screenshots heavily; the wider market is anyone with hundreds of unreviewed screenshots.

| Use case | What they screenshot | What they want back |
| --- | --- | --- |
| Job search (origin) | Job posts, recruiter messages | Which roles, at which companies, what they ask for |
| Learning | LinkedIn and X posts, tips, frameworks | The gist of each idea, findable later |
| Inspiration | UI, products, layouts, ads | A visual board by theme |
| People | Profiles, founders, contacts | Who they are and why they were saved |
| Everyday (wider market) | Recipes, products, receipts, directions, memes | Sorted out of the way, easy to clear |

**Behaviour learned so far (founder interview)**

- Backlog of hundreds of screenshots on iPhone.
- Uses it on demand — opens the app when ready to review, no push digests.
- Wants grouping by topic, short summaries and search; no tracker for job posts.
- Screenshots should stay in Photos after review, with the option to delete one or remove all similar ones.

## MVP scope

v1 does one job well: turn the existing screenshot pile into groups you can skim, search and clean up.

**In v1**

1. Photos access, limited to screenshots, with a clear privacy explanation.
2. First-run processing of the backlog, newest first, with visible progress.
3. Automatic topic groups, with a one-line gist per group.
4. A short summary for every screenshot.
5. Natural-language search across summaries and extracted text.
6. Delete a single screenshot, or remove all similar ones after a review step.
7. New screenshots processed the next time the app opens.
8. One export per category (e.g. jobs to a spreadsheet, posts to Notes).
9. Optional cloud processing (Boost): connect ChatGPT or add an OpenAI, Claude or Gemini API key; on-device stays the default.

**Not in v1**

- Job tracker or any status workflow
- Reminders, digests or push notifications
- Sharing and collaboration
- Editing groups by hand (to revisit after testing)
- Android, Mac, iPad

## Core flows and screens

Four screens cover v1: onboarding, home, group and search, with clean-up living inside group and detail views.

| Screen | What it shows | Key actions |
| --- | --- | --- |
| Onboarding | Why the app needs Photos access; "nothing leaves your phone" | Grant access, start processing |
| Home | Group cards with count and one-line gist; processing progress on first run | Open a group, search |
| Group | Screenshots as summary cards, newest first | Open detail, select, remove similar |
| Detail | Full screenshot, summary, extracted fields (company, role, name, link) | Open in Photos, open link, delete |
| Search | Results matched by meaning, not just exact words | Open result |

**Key flows**

1. **First run:** grant access → first groups appear within a minute or two → backlog keeps processing while the user browses.
2. **Review session:** open app → new screenshots are processed → skim groups → read summaries → open the few worth acting on.
3. **Find something:** search "that post about portfolio reviews" → matching screenshots with summaries.
4. **Clean up:** in a group, tap "remove similar" → review screen with matches pre-ticked → untick any to keep → one system confirmation deletes the rest.

## The item layer

Users browse items, not screenshots: each category shows a list of structured items extracted from the screenshots, and the image sits one tap deeper as the source.

- One item can come from several screenshots (a job post captured across 3 screens).
- Each category has its own fields, chosen for what is useful in that kind of screenshot.
- Items can be sorted and filtered by their fields (e.g. remote only, salary stated).

| Category | Item title | Fields shown in the list |
| --- | --- | --- |
| Jobs | Role | Company, location / remote, salary, seniority, date saved, link |
| Posts and ideas | The idea in one line | Author, platform, topic, date saved |
| People | Name | Title, company, why saved, profile link |
| Inspiration | What it shows | Source app or site, style, element (onboarding, pricing, nav) |
| Shopping | Product | Price, store, link |
| Receipts and docs | Merchant or document | Amount, date, category |
| Conversations | Who and about what | App, date |

**Bulk actions in a category**

Universal (every category): select items → delete their screenshots; keep the item, delete the screenshot; mark as reviewed; move to another category; merge into one item; copy or share as a text list.

| Category | Category-specific bulk actions |
| --- | --- |
| Jobs | Clear older than X weeks; open all links; export to spreadsheet; compare side by side |
| Posts and ideas | Save to Notes as a reading list; group by author |
| People | Open profiles; add to Contacts; export list |
| Inspiration | Make a Photos album or moodboard; share as images |
| Shopping | Open links; clear bought or old |
| Receipts and docs | Export for expenses (CSV or PDF); total by month |
| Conversations | Delete all (privacy clean-up) |

In v1: delete, keep item and delete screenshot, mark reviewed, move, and one export per category.

## Features

Triage mode is the heart of the app: it turns an overwhelming pile into a few minutes of swiping.

**Triage mode**

- One item card at a time, Tinder-style: swipe right to keep, swipe left to delete. Nothing else on the card's gestures.
- The card shows the item layer (title and key fields), with a tap to see the full screenshot.
- Always-visible undo for the last swipe.
- Deletes are queued during the session and committed together at the end with one iOS confirmation, since iOS asks to confirm every delete.
- Works across all items or inside one category.

**Full feature set**

| Feature | What it does | Phase |
| --- | --- | --- |
| Triage mode | Swipe right to keep, left to delete | v1 |
| New since last time | Home shows how many items are unreviewed and where to start | v1 |
| Links back to source | Detected URL, company or post opens the original in one tap | v1 |
| Rewards and progress | Counters, milestones, space freed (see Gamification) | v1 |
| Freshness flags | Job posts older than \~4 weeks marked "probably closed", with a bulk clear | v1.1 |
| Privacy sweep | Finds one-time codes, banking, boarding passes, private chats; suggests deleting | v1.1 |
| Learns from corrections | Moving an item teaches the app where similar ones go | v1.1 |
| Connections | Links a recruiter in People to the job at the same company; later, company pages | Later |
| Ask your screenshots | Questions across items, e.g. "which remote roles mention design systems?" | Later |

## Gamification and rewards

The app should make clearing screenshots feel as satisfying as finishing a workout: every swipe moves a number, and every milestone gets a moment.

**Principle: reward reviewing, not just deleting.** If only deletes are celebrated, people will delete things they need and stop trusting the app. Keeps count toward streaks too.

**Layer 1 — every swipe**

- Live counters at the top of triage: reviewed, deleted, space freed.
- Distinct haptics for keep and delete; a light, satisfying sound (off by default, toggle on).
- The card flies off with weight; the next card arrives instantly, no loading.

**Layer 2 — milestones in a session**

| Trigger | Moment |
| --- | --- |
| 10, 25, 50, 100, 250 swipes in a row | Streak badge pops with a stronger haptic and a one-liner |
| 100 MB, 500 MB, 1 GB freed | Space toast, translated into something felt: "That's room for \~200 photos" |
| A category reaches zero unreviewed | "Jobs: all clear" full-screen moment with confetti |
| Whole backlog reviewed | The big one: total cleared, space freed, time it took |

**Layer 3 — after the session**

- Session summary card: reviewed, deleted, space freed, and "3 jobs worth a look" pulled from what you kept. Shareable as an image.
- Backlog progress ring on home: "73% sorted".

**Layer 4 — over time**

- Lifetime stats: total cleared, total space freed, longest streak.
- Achievements: First 100, Gigabyte Club, Inbox Zero, Privacy Pro (cleared sensitive screenshots), Speed Run (100 in under 5 minutes).
- Personal bests: "New record: 142 in one session".
- Rediscovery: occasionally surface something kept long ago — "You saved this 6 months ago. Still useful?"

**Tone of the copy (examples)**

- "10 down. You're on a roll."
- "50 in a row. Your camera roll thanks you."
- "Freed 100 MB. That's a whole album's worth."
- "Jobs: all clear. Go apply to something."

**Guardrails**

- Undo is always one tap away, and deleted items sit in Recently Deleted for 30 days.
- No guilt notifications, no streaks that punish missing a day; the app is used on demand.
- Counters count committed deletes, so a cancelled confirmation never shows fake progress.
- Celebrations scale down after the first few times so they stay delightful, not noisy.

**To explore**

- [ ] Timed challenge: "5-minute clean-up" with a beat-your-best score
- [ ] Weekly recap card, opt-in only
- [ ] Visual identity of rewards: confetti, sticker-style badges, or something calmer
- [ ] Whether streaks across days fit an on-demand app at all

## Grouping, summaries and similarity

Groups come from a fixed set of base types plus topics the model finds; bulk delete only ever uses near-duplicates, never topic.

**Groups**

- **Base types (fixed):** Jobs, Posts and ideas, People, Inspiration, Shopping, Receipts and docs, Conversations, Other.
- **Topics (dynamic):** within a type, the model clusters by subject, e.g. Jobs → "Design roles in fintech". Topics need at least 3 screenshots to appear.
- Each screenshot belongs to one type and at most one topic.

**Summaries**

- One or two lines per screenshot, plus extracted fields by type: company, role and location for jobs; author and idea for posts; name and title for people.
- One-line gist per group, regenerated when the group changes.

**Three kinds of "similar"**

| Kind | Example | Used for bulk delete? |
| --- | --- | --- |
| Exact duplicate | Same screen captured twice | Yes |
| Same item, several screens | One job post across 3 screenshots | Yes, kept together as one item |
| Same topic | Five different design roles | No — too risky |

## Technical approach

The app is built on iOS 27, where Apple's Foundation Models framework accepts images alongside text and can call Vision OCR directly, all on-device.

&#91;embedded content: processing pipeline · 6 steps, all on-device\]

Each screenshot is read, understood once and stored locally; the app only ever works from that index.

- **Reading:** PhotoKit fetches the Screenshots album only; Vision OCR extracts text.
- **Understanding:** the on-device model returns structured output per screenshot: type, topic, summary and fields.
- **Search:** text embeddings stored locally for search by meaning; Core Spotlight LLM search as a possible extra.
- **Similarity:** image hashes for exact duplicates; text overlap plus time taken for multi-screen items.
- **Background work:** first run processes in batches; later runs handle only new screenshots when the app opens.
- **Fallback:** Private Cloud Compute for long or dense screenshots, still inside Apple's privacy model.
- **Requirement:** an Apple Intelligence-capable iPhone for the full experience.

## Model options

On-device stays the default; users who want sharper results can connect a cloud model through an optional "Boost" setting.

| Option | How the user connects | Billing | Status |
| --- | --- | --- | --- |
| Apple on-device (default) | Nothing to set up | Free | Available in iOS 27 |
| Sign in with ChatGPT | One-tap sign-in, user sets a weekly cap for the app | Uses the user's Plus or Pro plan allowance | Partner program; apply to be listed |
| OpenAI API key | User pastes their own key | Pay per use on the user's OpenAI account | Available |
| Claude API key | User pastes their own key | Pay per use on the user's Anthropic account | Available; Claude subscriptions can't be used by third-party apps |
| Gemini API key | User creates a key in Google AI Studio and pastes it | Pay per use on the user's Google account | Available; Google AI Pro and Ultra plans can't be used by third-party apps yet |

**How it works in the app**

- iOS 27's Foundation Models framework accepts cloud providers such as Claude through the same API as Apple's model, so switching is a per-session choice, not a rewrite.
- Send text, not images: OCR runs on the phone and only extracted text goes to the cloud, unless the user opts in to sending images.
- Use the cloud selectively: items the on-device model is unsure about, and "Ask your screenshots". Not every item.
- Mark items processed in the cloud, so the privacy promise stays honest.
- If a cap or key fails, fall back to on-device silently and say so in settings.

**Decisions**

- [ ] Apply to OpenAI's Sign in with ChatGPT partner program (the mass-market route)
- [ ] Ship API keys in v1 alongside Sign in with ChatGPT, since partner approval may take time
- [ ] Is image sending ever allowed, and for which categories?

Sources: [The New Stack](https://thenewstack.io/sign-in-with-chatgpt/) · [OpenAI Help](https://help.openai.com/en/articles/20001542) · [Trending Topics](https://www.trendingtopics.eu/sign-in-with-chatgpt-tokens-other-apps/) · [Claude Platform Docs](https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/apple-foundation-models)

Gemini subscription status: [Google AI Developers Forum](https://discuss.ai.google.dev/t/gemini-subscription-access-for-third-party-apps-is-a-sanctioned-program-planned/175577)

**Claude API key setup (v1)**

The app walks users through getting a Claude key with a short guided flow; most people have never made an API key, so each step gets its own screen.

&#91;embedded content: Claude key setup · 6 screens, app → Console → app\]

Steps 2 to 5 happen in the Claude Console in Safari; the app's tutorial screens show annotated screenshots of each Console page so users know where to tap.

1. **Start in the app:** Settings → Boost → Claude, then "Get a Claude key".
2. **Sign in:** opens [platform.claude.com](https://platform.claude.com/); log in or create an account.
3. **Add credits:** API use is billed per use to the user's Console account, separate from any Claude subscription.
4. **Create a key:** on the [API keys page](https://platform.claude.com/settings/keys), tap Create key and name it, e.g. "Screenshots".
5. **Copy the key:** it starts with `sk-ant-` and is shown only once; if lost, make a new one.
6. **Paste and test:** back in the app, paste the key; the app makes a tiny test call and shows "Connected".

**Design notes**

- Detect a copied `sk-ant-` key on the clipboard when the user returns, and offer to paste it.
- Store the key in the iOS Keychain; never show it in full again.
- Show an estimated monthly cost based on how many items go to the cloud.
- Tutorial screenshots of the Console need refreshing whenever its layout changes.

Source: [Get your Claude API key – Claude Platform Docs](https://platform.claude.com/docs/en/get-api-key)

## Risks and constraints

The biggest risk is device coverage: many iPhones that run iOS 27 cannot run Apple's on-device model.

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Device coverage | Unsupported iPhones get no summaries or smart groups | Lite mode: OCR + keyword grouping; decide early whether to offer it or require a supported device |
| Model quality | The on-device model is small; summaries may be generic | Test on a real backlog before building UI; keep summaries short and field-based |
| Processing time | Hundreds of screenshots on first run | Newest first, show early groups, continue in background while charging |
| Deletion trust | Wrongly removed screenshots break trust instantly | Review step before delete, near-duplicates only, iOS keeps deleted items 30 days |
| Photos permission | Users may refuse full library access | Explain value up front; support limited access |
| New APIs | iOS 27 frameworks are new and may change | Keep the AI layer behind one interface so models can be swapped |
| Differentiation | Apple Photos or Google could add the same feature | Lead on focus, speed and clean-up, not just search |

## Open questions to refine the MVP

These decide the shape of v1; each is a one-line call to make before design starts.

**Product**

- [ ] Does "remove all similar" also mean by topic (e.g. clear all memes), or only near-duplicates?
- [ ] Should a reviewed screenshot be marked "seen" so the home screen shows what's new?
- [ ] Can users rename, merge or move groups in v1, or only later?
- [ ] Are base types visible to the user, or only the topic groups?
- [ ] Does the app link back to the source (job URL, LinkedIn post) when it can read one?

**Business**

- [ ] Free, paid upfront, or subscription? What would the founder pay?
- [ ] What happens on unsupported iPhones: lite mode, or not supported?
- [ ] Lead market: job seekers first, or general screenshot clutter from day one?

**Brand**

- [ ] Name and tone: utility ("Screenshot Sorter") or something warmer?

## Next steps

Step 1 is the go/no-go: if the on-device model can't sort and summarise a real backlog well, the plan changes.

- [ ] Answer the open questions above
- [ ] Prototype the pipeline on the founder's own screenshots and rate grouping and summary quality
- [ ] Lock the base types and similarity rules from what the prototype shows
- [ ] Design the four core screens and the clean-up flow
- [ ] Decide the unsupported-device strategy
- [ ] Interview 10–20 people: screenshot habits, backlog size, willingness to pay

## Sources

- [What's new in iOS 27 – Apple Developer](https://developer.apple.com/wwdc26/guides/ios/)
- [Foundation Models image input in iOS 27 – Blake Crosley](https://blakecrosley.com/blog/foundation-models-image-input-ios-27)
- [Foundation Models & Apple Intelligence – drobinin.com](https://drobinin.com/consulting/foundation-models-apple-intelligence/)
