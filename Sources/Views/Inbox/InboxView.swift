import SwiftUI

/// Inbox / Dump — raw input not yet fully organized.
struct InboxView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?

    /// Inbox items = nodes with source "quick_add" or "dump" that haven't been
    /// promoted/linked yet (low link count as proxy).
    private var inboxItems: [MindNode] {
        store.nodes.values
            .filter { $0.sourceOrigin == "quick_add" || $0.sourceOrigin == "dump" || $0.sourceOrigin == "file_drop" }
            .filter { store.linksFor(nodeID: $0.id).count < 2 }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List(inboxItems) { node in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.type.icon)
                    Text(node.title).font(.headline).lineLimit(1)
                    Spacer()
                    ConfidenceBadge(value: node.confidence)
                }
                if !node.body.isEmpty {
                    Text(node.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack {
                    Text(node.createdAt, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(store.linksFor(nodeID: node.id).count) links")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedNode = node }
        }
        .navigationTitle("Inbox")
        .overlay {
            if inboxItems.isEmpty {
                ContentUnavailableView("Inbox Empty", systemImage: "tray",
                    description: Text("Use Quick Add to dump thoughts here."))
            }
        }
    }
}
