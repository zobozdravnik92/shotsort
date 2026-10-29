import SwiftData
import SwiftUI

struct CategoryListView: View {
    let category: ItemCategory

    @Query private var items: [Item]
    @State private var sort = SortOrder.newest
    @State private var unreviewedOnly = false
    @State private var remoteOnly = false
    @State private var triage: TriageTarget?
    @Environment(\.theme) private var theme

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case title = "Title"
        var id: String { rawValue }
    }

    init(category: ItemCategory) {
        self.category = category
        let categoryRaw = category.rawValue
        _items = Query(
            filter: #Predicate<Item> { $0.categoryRaw == categoryRaw && $0.statusRaw != "deleted" },
            sort: \Item.savedAt,
            order: .reverse
        )
    }

    private var shown: [Item] {
        var list = items
        if unreviewedOnly { list = list.filter { $0.status == .new } }
        if remoteOnly { list = list.filter { $0.fields["remote"]?.lowercased() == "yes" } }
        if sort == .title {
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return list
    }

    private var unreviewedCount: Int { items.filter { $0.status == .new }.count }

    private var subtitle: String {
        let count = items.count == 1 ? "1 item" : "\(items.count) items"
        return unreviewedCount == 0 ? count : "\(count) · \(unreviewedCount) new"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ScreenHeader(title: category.name, subtitle: subtitle)
                if shown.isEmpty {
                    ThemedPanel(category: category) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(theme.text("Nothing here")).font(theme.font(20))
                            Text("Try turning off a filter.").font(.subheadline).opacity(0.7)
                        }
                    }
                }
                ForEach(shown) { item in
                    NavigationLink(value: item) {
                        ItemRow(item: item)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .themedNavigation(category.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Unreviewed only", isOn: $unreviewedOnly)
                    if category == .jobs {
                        Toggle("Remote only", isOn: $remoteOnly)
                    }
                } label: {
                    Label("Sort and filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomBar(fade: theme.background) {
                WideButton(title: unreviewedCount == 0 ? "All reviewed" : "Triage \(unreviewedCount) new", systemImage: "rectangle.stack") {
                    triage = TriageTarget(category: category)
                }
                .disabled(unreviewedCount == 0)
            }
        }
        .fullScreenCover(item: $triage) { TriageView(category: $0.category) }
    }
}

#Preview {
    NavigationStack {
        CategoryListView(category: .jobs)
            .navigationDestination(for: Item.self) { ItemDetailView(item: $0) }
    }
    .environment(AppServices.preview)
    .modelContainer(AppServices.preview.container)
}
