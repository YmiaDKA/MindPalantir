import SwiftUI

/// Inbox / Dump — raw input not yet fully organized.
/// Items here need to be promoted by linking to projects.
struct InboxView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @State private var promotingNode: MindNode?

    /// Inbox items = nodes with source "quick_add" or "dump" that haven't been
    /// promoted/linked yet (low link count as proxy).
    private var inboxItems: [MindNode] {
        store.nodes.values
            .filter { $0.sourceOrigin == "quick_add" || $0.sourceOrigin == "dump" || $0.sourceOrigin == "file_drop" || $0.sourceOrigin == "ai_chat" }
            .filter { store.linksFor(nodeID: $0.id).count < 2 }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var activeProjects: [MindNode] {
        store.activeNodes(ofType: .project)
    }

    var body: some View {
        List(inboxItems) { node in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: node.type.sfIcon)
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

                    // Quick promote button
                    Menu {
                        ForEach(activeProjects) { project in
                            Button {
                                promote(node, to: project)
                            } label: {
                                Label(project.title, systemImage: "folder")
                            }
                        }
                        Divider()
                        Button {
                            // Convert to task
                            var updated = node
                            updated.type = .task
                            updated.sourceOrigin = "promoted"
                            updated.updatedAt = .now
                            try? store.insertNode(updated)
                        } label: {
                            Label("Convert to Task", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    .menuStyle(.borderlessButton)
                    .help("Promote to project")
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

    private func promote(_ node: MindNode, to project: MindNode) {
        // Link to project
        let linkType: LinkType = node.type == .source ? .fromSource : .belongsTo
        if !store.linkExists(sourceID: project.id, targetID: node.id, type: linkType) {
            try? store.insertLink(MindLink(sourceID: project.id, targetID: node.id, linkType: linkType))
        }

        // Mark as promoted
        var updated = node
        updated.sourceOrigin = "promoted"
        updated.relevance = min(1.0, updated.relevance + 0.1)
        updated.updatedAt = .now
        try? store.insertNode(updated)
    }
}
