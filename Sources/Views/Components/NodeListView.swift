import SwiftUI

/// Generic list for a node type.
struct NodeListView: View {
    @Environment(NodeStore.self) private var store
    let type: NodeType
    @Binding var selectedNode: MindNode?

    var body: some View {
        List(store.nodes(ofType: type)) { node in
            HStack {
                Text(node.type.icon)
                VStack(alignment: .leading) {
                    Text(node.title).font(.headline).lineLimit(1)
                    if !node.body.isEmpty {
                        Text(node.body).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                ConfidenceBadge(value: node.confidence)
                RelevanceBar(value: node.relevance).frame(width: 40, height: 3)
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedNode = node }
        }
        .navigationTitle(type.rawValue.capitalized)
    }
}

/// Projects with connection counts.
struct ProjectListView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?

    var body: some View {
        List(store.activeNodes(ofType: .project)) { node in
            let connections = store.connectedNodes(for: node.id).count
            HStack {
                Image(systemName: "folder.fill").foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text(node.title).font(.headline)
                    Text("\(connections) items · \(node.status.rawValue)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                RelevanceBar(value: node.relevance).frame(width: 40, height: 3)
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedNode = node }
        }
        .navigationTitle("Projects")
    }
}
