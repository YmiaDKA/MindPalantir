import SwiftUI

/// Needs Clarification — uncertain system decisions.
/// Shows possible duplicates, low-confidence items, weak links.
struct ClarificationView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?

    private var uncertain: [MindNode] {
        store.uncertainNodes(limit: 30)
    }

    var body: some View {
        List(uncertain) { node in
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: node.type.sfIcon)
                        .foregroundStyle(Theme.Colors.typeColor(node.type))
                    Text(node.title)
                        .font(Theme.Fonts.headline)
                        .lineLimit(1)
                    Spacer()
                    ConfidenceBadge(value: node.confidence)
                }

                Text(reasonFor(node: node))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.orange)

                if !node.body.isEmpty {
                    Text(node.body)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("Source: \(node.sourceOrigin ?? "unknown")")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Looks Fine") { boostConfidence(node) }
                        .font(Theme.Fonts.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(Theme.Colors.accent)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle())
            .onTapGesture { selectedNode = node }
        }
        .listStyle(.plain)
        .navigationTitle("Needs Clarification")
        .overlay {
            if uncertain.isEmpty {
                ContentUnavailableView("All Clear", systemImage: "checkmark.circle",
                    description: Text("No uncertain items. Everything looks good."))
            }
        }
    }

    private func reasonFor(node: MindNode) -> String {
        if node.confidence < 0.3 { return "Very low confidence — may be misclassified" }
        if node.sourceOrigin == nil || node.sourceOrigin?.isEmpty == true { return "Unknown source" }
        if store.linksFor(nodeID: node.id).isEmpty { return "No connections — is this relevant?" }
        return "Low confidence in classification"
    }

    private func boostConfidence(_ node: MindNode) {
        var updated = node
        updated.confidence = min(1.0, node.confidence + 0.3)
        updated.updatedAt = .now
        try? store.insertNode(updated)
    }
}
