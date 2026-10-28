import SwiftData
import SwiftUI

struct CategoryListView: View {
    let category: ItemCategory

    @Query private var items: [Item]
    @State private var sort = SortOrder.newest
    @State private var unreviewedOnly = false
    @State private var remoteOnly = false
    @State private var triage: TriageTarget?

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

    var body: some View {
        List(shown) { item in
            NavigationLink(value: item) {
                ItemRow(item: item)
            }
        }
        .overlay {
            if shown.isEmpty {
                ContentUnavailableView("Nothing here", systemImage: category.symbol, description: Text("Try turning off a filter."))
            }
        }
        .navigationTitle(category.name)
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
            ToolbarItem(placement: .bottomBar) {
                Button {
                    triage = TriageTarget(category: category)
                } label: {
                    Label(unreviewedCount == 0 ? "All reviewed" : "Triage \(unreviewedCount) new", systemImage: "rectangle.stack")
                        .labelStyle(.titleAndIcon)
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
