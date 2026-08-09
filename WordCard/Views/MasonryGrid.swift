import SwiftUI

/// A custom Masonry / Staggered Grid layout that renders cards with variable aspect ratios across dynamic columns.
struct MasonryGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let minimumColumnWidth: CGFloat
    let spacing: CGFloat
    let itemAspectRatio: (Item) -> Double
    let content: (Item) -> Content

    init(
        items: [Item],
        minimumColumnWidth: CGFloat = 240,
        spacing: CGFloat = 16,
        itemAspectRatio: @escaping (Item) -> Double,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.minimumColumnWidth = max(1, minimumColumnWidth)
        self.spacing = spacing
        self.itemAspectRatio = itemAspectRatio
        self.content = content
    }

    var body: some View {
        MasonryLayout(minimumColumnWidth: minimumColumnWidth, spacing: spacing) {
            ForEach(items) { item in
                content(item)
                    .layoutValue(
                        key: MasonryAspectRatioKey.self,
                        value: max(0.2, min(5.0, itemAspectRatio(item)))
                    )
            }
        }
    }
}

private struct MasonryAspectRatioKey: LayoutValueKey {
    static let defaultValue = 1.0
}

/// Reports its complete height to its parent, allowing a surrounding vertical
/// ScrollView to calculate the correct scrollable content size.
private struct MasonryLayout: Layout {
    let minimumColumnWidth: CGFloat
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = max(1, proposal.width ?? minimumColumnWidth)
        let metrics = layoutMetrics(width: width, subviews: subviews)
        return CGSize(width: width, height: metrics.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let metrics = layoutMetrics(width: bounds.width, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let position = metrics.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(
                    width: metrics.columnWidth,
                    height: metrics.itemHeights[index]
                )
            )
        }
    }

    private func layoutMetrics(width: CGFloat, subviews: Subviews) -> Metrics {
        let columnCount = max(1, Int(width / minimumColumnWidth))
        let totalSpacing = CGFloat(columnCount - 1) * spacing
        let columnWidth = max(1, (width - totalSpacing) / CGFloat(columnCount))
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)
        var positions: [CGPoint] = []
        var itemHeights: [CGFloat] = []

        for subview in subviews {
            let column = columnHeights.indices.min {
                columnHeights[$0] < columnHeights[$1]
            } ?? 0
            let aspectRatio = max(0.2, min(5.0, subview[MasonryAspectRatioKey.self]))
            let itemHeight = columnWidth / CGFloat(aspectRatio)
            let itemY = columnHeights[column] == 0
                ? 0
                : columnHeights[column] + spacing

            positions.append(CGPoint(
                x: CGFloat(column) * (columnWidth + spacing),
                y: itemY
            ))
            itemHeights.append(itemHeight)
            columnHeights[column] = itemY + itemHeight
        }

        return Metrics(
            columnWidth: columnWidth,
            height: columnHeights.max() ?? 0,
            positions: positions,
            itemHeights: itemHeights
        )
    }

    private struct Metrics {
        let columnWidth: CGFloat
        let height: CGFloat
        let positions: [CGPoint]
        let itemHeights: [CGFloat]
    }
}
