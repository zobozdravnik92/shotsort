import SwiftData
import SwiftUI

/// Opens the search screen from Home.
struct SearchRoute: Hashable {}

/// The "Find in your screenshots" field on Home. Tapping it opens the search screen.
struct SearchField: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
            Text(theme.text("Find in your screenshots"))
                .font(.system(size: 17, weight: .medium, design: theme.fontDesign))
                .opacity(0.6)
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.cardInk(.other))
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background { RoundedRectangle(cornerRadius: theme.radius(18), style: .continuous).fill(theme.cardFill(.other)).themedShadow(theme) }
        .overlay {
            if let outline = theme.cardOutline {
                RoundedRectangle(cornerRadius: theme.radius(18), style: .continuous).strokeBorder(outline, lineWidth: theme.outlineWidth)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Find in your screenshots")
        .accessibilityAddTraits(.isSearchField)
    }
}

/// Searches titles, summaries, details and the text read from screenshots, on the phone.
struct SearchView: View {
    @Query(filter: #Predicate<Item> { $0.statusRaw != "deleted" }, sort: \Item.savedAt, order: .reverse)
    private var items: [Item]
    @State private var query = ""
    @FocusState private var focused: Bool
    @Environment(\.theme) private var theme

    private var results: [ItemSearch.Result] { ItemSearch.search(query, in: items) }

    var body: some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        ScrollView {
            LazyVStack(spacing: 8) {
                field
                    .padding(.bottom, 8)

                if trimmed.isEmpty {
                    Text("Search titles, summaries and the words in your screenshots. Everything stays on this iPhone.")
                        .font(.system(.subheadline, design: theme.fontDesign))
                        .foregroundStyle(theme.fadedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: trimmed)
                        .foregroundStyle(theme.ink)
                        .padding(.top, 40)
                } else {
                    Text(results.count == 1 ? "1 result" : "\(results.count) results")
                        .font(.system(size: 13, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.fadedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                    ForEach(results, id: \.item.id) { result in
                        NavigationLink(value: result.item) {
                            ItemRow(item: result.item, snippet: result.snippet)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { ThemedBackground() }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .accessibilityHidden(true)
            TextField("Find in your screenshots", text: $query)
                .font(.system(size: 17, weight: .medium, design: theme.fontDesign))
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { query = "" }
                    .labelStyle(.iconOnly)
                    .opacity(0.5)
            }
        }
        .foregroundStyle(theme.cardInk(.other))
        .tint(theme.cardInk(.other))
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(theme.cardFill(.other), in: RoundedRectangle(cornerRadius: theme.radius(18), style: .continuous))
        .overlay {
            if let outline = theme.cardOutline {
                RoundedRectangle(cornerRadius: theme.radius(18), style: .continuous).strokeBorder(outline, lineWidth: theme.outlineWidth)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
            .navigationDestination(for: Item.self) { ItemDetailView(item: $0) }
    }
    .environment(AppServices.preview)
    .modelContainer(AppServices.preview.container)
}
