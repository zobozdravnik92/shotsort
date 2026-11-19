import SwiftData
import SwiftUI

struct CategoryListView: View {
    let category: ItemCategory

    @Query private var items: [Item]
    @State private var sort = SortOrder.newest
    @State private var unreviewedOnly = false
    @State private var remoteOnly = false
    @State private var triage: TriageTarget?
    @State private var opened: Item?
    @State private var peek: Item?
    @State private var peekOffset: CGSize = .zero
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(AppServices.self) private var services

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
                    PeekableRow(item: item, peek: $peek, peekOffset: $peekOffset) {
                        opened = item
                    } onDelete: {
                        await delete(item)
                    }
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
        .navigationDestination(item: $opened) { ItemDetailView(item: $0) }
        .overlay {
            if let peek {
                PeekOverlay(item: peek, offset: peekOffset)
            }
        }
        .animation(.spring(duration: 0.14, bounce: 0.1), value: peek?.id)
    }

    /// Deletes the item's screenshots (iOS asks to confirm) and erases what was read from them.
    private func delete(_ item: Item) async {
        _ = await DeleteCommitter.deleteItem(item, deleter: services.deleter, context: context)
    }
}

/// A card that opens on tap. Press and hold to preview the screenshot; keep holding and flick to delete.
private struct PeekableRow: View {
    let item: Item
    @Binding var peek: Item?
    @Binding var peekOffset: CGSize
    let onOpen: () -> Void
    let onDelete: () async -> Void

    var body: some View {
        ItemRow(item: item)
            .scaleEffect(peek?.id == item.id ? 0.97 : 1)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .gesture(
                PressAndDragGesture {
                    Haptics.keep()
                    peekOffset = .zero
                    peek = item
                } onChanged: { translation in
                    peekOffset = translation
                } onEnded: { translation, velocity in
                    if Peek.isDelete(translation: translation.width, velocity: velocity) {
                        flyOffAndDelete()
                    } else {
                        close()
                    }
                } onCancelled: {
                    close()
                }
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Touch and hold to preview the screenshot.")
            .accessibilityAction(named: "Delete") { Task { await onDelete() } }
    }

    private func flyOffAndDelete() {
        Haptics.delete()
        withAnimation(.easeOut(duration: 0.2)) {
            peekOffset = CGSize(width: Peek.deleteDirection * 700, height: peekOffset.height + 60)
        } completion: {
            peek = nil
            peekOffset = .zero
            Task { await onDelete() }
        }
    }

    private func close() {
        withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
            peek = nil
            peekOffset = .zero
        }
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
