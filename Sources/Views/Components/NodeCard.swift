import SwiftUI

/// A card for any node — used in Today, lists, projects.
struct NodeCard: View {
    let node: MindNode
    @Binding var selectedNode: MindNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(node.type.icon)
                Text(node.type.rawValue.capitalized)
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if node.pinned {
                    Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                }
                RelevanceBar(value: node.relevance).frame(width: 36, height: 3)
            }

            Text(node.title).font(.subheadline.bold()).lineLimit(2)

            if !node.body.isEmpty {
                Text(node.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }

            HStack {
                ConfidenceBadge(value: node.confidence)
                Spacer()
                Text(node.updatedAt, style: .relative)
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selectedNode?.id == node.id ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture { selectedNode = node }
    }
}

/// Task-specific row with status toggle.
struct TaskRow: View {
    @Environment(NodeStore.self) private var store
    let task: MindNode
    @Binding var selectedNode: MindNode?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                toggleDone()
            } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.status == .completed)
                    .lineLimit(1)
                if let due = task.dueDate {
                    Text("Due \(due, style: .date)")
                        .font(.caption2)
                        .foregroundStyle(due < .now ? .red : .secondary)
                }
            }

            Spacer()

            RelevanceBar(value: task.relevance).frame(width: 30, height: 3)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = task }
    }

    private func toggleDone() {
        var updated = task
        updated.status = task.status == .completed ? .active : .completed
        updated.updatedAt = .now
        try? store.insertNode(updated)
    }
}

/// Clarification card — shows uncertainty.
struct ClarificationCard: View {
    let node: MindNode
    @Binding var selectedNode: MindNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(node.type.icon)
                Text(node.title).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                ConfidenceBadge(value: node.confidence)
            }
            Text(reasonForClarification)
                .font(.caption).foregroundStyle(.orange)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .onTapGesture { selectedNode = node }
    }

    private var reasonForClarification: String {
        if node.confidence < 0.3 { return "Very low confidence — needs manual review" }
        if node.sourceOrigin == nil { return "Unknown source — is this correct?" }
        return "Low confidence classification"
    }
}
