import SwiftUI

/// One category's numbers for the Home mosaic.
struct CategorySummary: Identifiable, Equatable {
    let category: ItemCategory
    let itemCount: Int
    let screenshotCount: Int
    let unreviewedCount: Int

    var id: ItemCategory { category }
}

/// Lays out category cards so bigger piles get bigger cards.
/// A category holding at least `heroShare` of all screenshots gets a full-width card;
/// the rest go in two columns, each card placed in the shorter column, tallest first.
enum MosaicLayout {
    struct Tile: Equatable {
        let summary: CategorySummary
        let height: CGFloat
    }

    struct Result: Equatable {
        var hero: Tile?
        var left: [Tile] = []
        var right: [Tile] = []
    }

    static let minHeight: CGFloat = 120
    static let maxHeight: CGFloat = 190
    static let heroHeight: CGFloat = 150
    static let heroShare = 0.4
    static let spacing: CGFloat = 12

    static func layout(_ summaries: [CategorySummary]) -> Result {
        let sorted = summaries
            .filter { $0.itemCount > 0 }
            .sorted { ($0.screenshotCount, $1.category.rawValue) > ($1.screenshotCount, $0.category.rawValue) }
        guard let largest = sorted.first else { return Result() }

        var result = Result()
        var rest = sorted[...]
        let total = sorted.reduce(0) { $0 + $1.screenshotCount }
        if sorted.count == 1 || Double(largest.screenshotCount) >= Double(total) * heroShare {
            result.hero = Tile(summary: largest, height: heroHeight)
            rest = rest.dropFirst()
        }

        let maxCount = max(rest.first?.screenshotCount ?? 1, 1)
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        for summary in rest {
            let tile = Tile(summary: summary, height: height(for: summary.screenshotCount, maxCount: maxCount))
            if leftHeight <= rightHeight {
                result.left.append(tile)
                leftHeight += tile.height + spacing
            } else {
                result.right.append(tile)
                rightHeight += tile.height + spacing
            }
        }
        return result
    }

    /// Square root keeps small piles readable while big ones still stand out.
    static func height(for count: Int, maxCount: Int) -> CGFloat {
        let share = (Double(max(count, 0)) / Double(max(maxCount, 1))).squareRoot()
        return (minHeight + (maxHeight - minHeight) * share).rounded()
    }
}

struct CategoryMosaic: View {
    let summaries: [CategorySummary]

    var body: some View {
        let result = MosaicLayout.layout(summaries)
        VStack(spacing: MosaicLayout.spacing) {
            if let hero = result.hero {
                card(hero, isHero: true)
            }
            HStack(alignment: .top, spacing: MosaicLayout.spacing) {
                column(result.left)
                column(result.right)
            }
        }
    }

    private func column(_ tiles: [MosaicLayout.Tile]) -> some View {
        VStack(spacing: MosaicLayout.spacing) {
            ForEach(tiles, id: \.summary.id) { card($0, isHero: false) }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func card(_ tile: MosaicLayout.Tile, isHero: Bool) -> some View {
        NavigationLink(value: tile.summary.category) {
            CategoryCard(summary: tile.summary, isHero: isHero)
                .frame(height: tile.height)
        }
        .buttonStyle(PressableCardStyle())
    }
}

/// Cards shrink slightly while pressed.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

#Preview {
    ScrollView {
        CategoryMosaic(summaries: [
            .init(category: .other, itemCount: 14, screenshotCount: 14, unreviewedCount: 14),
            .init(category: .jobs, itemCount: 3, screenshotCount: 4, unreviewedCount: 2),
            .init(category: .posts, itemCount: 6, screenshotCount: 6, unreviewedCount: 1),
            .init(category: .people, itemCount: 1, screenshotCount: 1, unreviewedCount: 1),
            .init(category: .shopping, itemCount: 2, screenshotCount: 2, unreviewedCount: 0),
        ])
        .padding()
    }
    .background(Theme.sunshine.background)
    .environment(AppServices.preview)
}
