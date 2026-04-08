import SwiftUI

/// Chronological activity stream grouped by day.
struct TimelineView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?

    private var groupedByDay: [(String, [MindNode])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let nodes = store.recentNodes(days: 30, limit: 50)
        let grouped = Dictionary(grouping: nodes) { node in
            formatter.string(from: node.updatedAt)
        }
        return grouped.sorted { a, b in
            guard let d1 = nodes.first(where: { formatter.string(from: $0.updatedAt) == a.key })?.updatedAt,
                  let d2 = nodes.first(where: { formatter.string(from: $0.updatedAt) == b.key })?.updatedAt
            else { return false }
            return d1 > d2
        }
    }

    var body: some View {
        List {
            ForEach(groupedByDay, id: \.0) { day, nodes in
                Section(day) {
                    ForEach(nodes) { node in
                        HStack(spacing: 10) {
                            Text(node.type.icon)
                            VStack(alignment: .leading) {
                                Text(node.title).font(.subheadline.bold()).lineLimit(1)
                                Text(node.updatedAt, style: .time)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ConfidenceBadge(value: node.confidence)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNode = node }
                    }
                }
            }
        }
        .navigationTitle("Timeline")
    }
}
