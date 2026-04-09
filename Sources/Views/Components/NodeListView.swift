import SwiftUI

/// Generic list for a node type — filterable, sortable, grouped.
struct NodeListView: View {
    @Environment(NodeStore.self) private var store
    let type: NodeType
    @Binding var selectedNode: MindNode?
    @State private var sortMode: SortMode = .relevance
    @State private var filterStatus: NodeStatus? = nil
    @State private var searchText = ""
    
    enum SortMode: String, CaseIterable {
        case relevance = "Relevance"
        case recent = "Recent"
        case title = "A-Z"
    }
    
    private var filteredNodes: [MindNode] {
        var nodes = store.nodes(ofType: type)
        
        // Filter by status
        if let status = filterStatus {
            nodes = nodes.filter { $0.status == status }
        }
        
        // Filter by search — use FTS5 results
        if !searchText.isEmpty {
            let ftsResults = Set(store.search(searchText, limit: 50).map { $0.id })
            nodes = nodes.filter { ftsResults.contains($0.id) }
        }
        
        // Sort
        switch sortMode {
        case .relevance:
            nodes.sort { $0.relevance > $1.relevance }
        case .recent:
            nodes.sort { $0.updatedAt > $1.updatedAt }
        case .title:
            nodes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        return nodes
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Filter bar
            filterBar
            
            Divider()
            
            // List
            List {
                ForEach(filteredNodes) { node in
                    NodeListRow(node: node, store: store, selectedNode: $selectedNode)
                }
                .onDelete(perform: deleteNodes)
            }
            .listStyle(.plain)
        }
        .navigationTitle(type.rawValue.capitalized)
        .searchable(text: $searchText, prompt: "Search \(type.rawValue)s...")
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Sort picker
                Menu {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Button { sortMode = mode } label: {
                            HStack {
                                Text(mode.rawValue)
                                if sortMode == mode { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Label(sortMode.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                
                // Status filters
                statusButton(nil, label: "All")
                ForEach([NodeStatus.active, .completed, .archived, .draft], id: \.self) { status in
                    statusButton(status, label: status.rawValue.capitalized)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func deleteNodes(at offsets: IndexSet) {
        for index in offsets {
            let node = filteredNodes[index]
            try? store.deleteNode(id: node.id)
        }
    }

    private func statusButton(_ status: NodeStatus?, label: String) -> some View {
        Button {
            filterStatus = filterStatus == status ? nil : status
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    filterStatus == status ? Color.accentColor.opacity(0.15) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .foregroundStyle(filterStatus == status ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - List Row

struct NodeListRow: View {
    let node: MindNode
    let store: NodeStore
    @Binding var selectedNode: MindNode?
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: node.type.sfIcon)
                .font(.system(size: 16))
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(node.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if !node.body.isEmpty {
                    Text(node.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(node.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    let links = store.linksFor(nodeID: node.id).count
                    if links > 0 {
                        Text("· \(links) links")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Status + scores
            VStack(alignment: .trailing, spacing: 4) {
                ConfidenceBadge(value: node.confidence)
                RelevanceBar(value: node.relevance).frame(width: 40, height: 3)
                if node.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = node }
    }
}

// MARK: - Project List with Drill-Down

struct ProjectListView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.activeNodes(ofType: .project)) { node in
                    let connections = store.connectedNodes(for: node.id).count
                    let tasks = store.children(of: node.id, linkType: .belongsTo).filter { $0.type == .task }
                    let completedTasks = tasks.filter { $0.status == .completed }.count

                    NavigationLink(value: node.id) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(node.title)
                                    .font(.headline)

                                HStack(spacing: 8) {
                                    if !tasks.isEmpty {
                                        HStack(spacing: 4) {
                                            ProgressView(value: Double(completedTasks), total: Double(tasks.count))
                                                .frame(width: 40)
                                                .controlSize(.mini)
                                            Text("\(completedTasks)/\(tasks.count)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Text("\(connections) items")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                ConfidenceBadge(value: node.confidence)
                                RelevanceBar(value: node.relevance).frame(width: 40, height: 3)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = node }
                }
                .onDelete { offsets in
                    let projects = store.activeNodes(ofType: .project)
                    for index in offsets {
                        try? store.deleteNode(id: projects[index].id)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Projects")
            .navigationDestination(for: UUID.self) { id in
                if let project = store.nodes[id] {
                    ProjectDetailView(project: project, selectedNode: $selectedNode)
                }
            }
        }
    }
}
