import SwiftUI

/// Generic list for a node type — filterable, sortable, grouped.
/// Keyboard navigation: ↑↓/J/K to move, Enter to select, Escape to deselect.
struct NodeListView: View {
    @Environment(NodeStore.self) private var store
    let type: NodeType
    @Binding var selectedNode: MindNode?
    @State private var sortMode: SortMode = .relevance
    @State private var filterStatus: NodeStatus? = nil
    @State private var searchText = ""
    @State private var focusedNodeID: UUID?

    enum SortMode: String, CaseIterable {
        case relevance = "Relevance"
        case recent = "Recent"
        case title = "A-Z"
    }

    private var filteredNodes: [MindNode] {
        var nodes = store.nodes(ofType: type)

        if let status = filterStatus {
            nodes = nodes.filter { $0.status == status }
        }

        if !searchText.isEmpty {
            let ftsResults = Set(store.search(searchText, limit: 50).map { $0.id })
            nodes = nodes.filter { ftsResults.contains($0.id) }
        }

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
            filterBar

            Divider()

            List(selection: $focusedNodeID) {
                ForEach(filteredNodes) { node in
                    NodeListRow(node: node, store: store, selectedNode: $selectedNode)
                        .focusRing(isFocused: focusedNodeID == node.id, style: .subtle)
                        .tag(node.id)
                }
                .onDelete(perform: deleteNodes)
            }
            .listStyle(.plain)
        }
        .navigationTitle(type.rawValue.capitalized)
        .searchable(text: $searchText, prompt: "Search \\(type.rawValue)s...")
        // Keyboard navigation
        .onKeyPress(.return) {
            if let id = focusedNodeID, let node = filteredNodes.first(where: { $0.id == id }) {
                selectedNode = node
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if focusedNodeID != nil {
                focusedNodeID = nil
                return .handled
            }
            selectedNode = nil
            return .handled
        }
        .onKeyPress("j") { moveListFocus(direction: 1); return .handled }
        .onKeyPress("k") { moveListFocus(direction: -1); return .handled }
    }
    
    private func moveListFocus(direction: Int) {
        let nodes = filteredNodes
        guard !nodes.isEmpty else { return }
        
        if let currentID = focusedNodeID,
           let currentIndex = nodes.firstIndex(where: { $0.id == currentID }) {
            let newIndex = max(0, min(nodes.count - 1, currentIndex + direction))
            focusedNodeID = nodes[newIndex].id
        } else {
            focusedNodeID = direction > 0 ? nodes.first?.id : nodes.last?.id
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
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
                        .font(Theme.Fonts.caption)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                }
                .menuStyle(.borderlessButton)

                statusButton(nil, label: "All")
                ForEach([NodeStatus.active, .completed, .archived, .draft], id: \.self) { status in
                    statusButton(status, label: status.rawValue.capitalized)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
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
                .font(Theme.Fonts.caption)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    filterStatus == status ? Theme.Colors.accent.opacity(0.15) : Color.clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
                )
                .foregroundStyle(filterStatus == status ? Theme.Colors.accent : .secondary)
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
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: node.type.sfIcon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.typeColor(node.type))

            VStack(alignment: .leading, spacing: 3) {
                Text(node.title)
                    .font(Theme.Fonts.headline)
                    .lineLimit(1)
                if !node.body.isEmpty {
                    Text(node.body)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(node.updatedAt, style: .relative)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                    let links = store.linksFor(nodeID: node.id).count
                    if links > 0 {
                        Text("· \(links) links")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                ConfidenceBadge(value: node.confidence)
                RelevanceBar(value: node.relevance).frame(width: 40, height: 3)
                if node.pinned {
                    Image(systemName: "pin.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = node }
    }
}

// MARK: - Project List with Drill-Down

struct ProjectListView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    var onOpenProject: ((MindNode) -> Void)?
    @State private var viewMode: ViewMode = .cards
    @State private var focusedProjectID: UUID?

    enum ViewMode: String, CaseIterable {
        case cards = "Cards"
        case list = "List"
    }

    private var sortedProjects: [MindNode] {
        store.activeNodes(ofType: .project)
            .sorted { ($0.pinned ? 1 : 0) + $0.relevance > ($1.pinned ? 1 : 0) + $1.relevance }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with view toggle
            HStack {
                Text("Projects")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                Text("\(sortedProjects.count) active")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            if viewMode == .cards {
                projectCards
            } else {
                projectList
            }
        }
        // Keyboard navigation
        .onKeyPress(.return) {
            if let id = focusedProjectID, let project = sortedProjects.first(where: { $0.id == id }) {
                if let onOpenProject { onOpenProject(project) }
                else { selectedNode = project }
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if focusedProjectID != nil {
                focusedProjectID = nil
                return .handled
            }
            selectedNode = nil
            return .handled
        }
        .onKeyPress("j") { moveFocus(direction: 1); return .handled }
        .onKeyPress("k") { moveFocus(direction: -1); return .handled }
        .onKeyPress(.downArrow) { moveFocus(direction: 1); return .handled }
        .onKeyPress(.upArrow) { moveFocus(direction: -1); return .handled }
    }
    
    private func moveFocus(direction: Int) {
        let projects = sortedProjects
        guard !projects.isEmpty else { return }
        
        if let currentID = focusedProjectID,
           let currentIndex = projects.firstIndex(where: { $0.id == currentID }) {
            let newIndex = max(0, min(projects.count - 1, currentIndex + direction))
            focusedProjectID = projects[newIndex].id
        } else {
            focusedProjectID = direction > 0 ? projects.first?.id : projects.last?.id
        }
    }

    // MARK: - Card Grid

    private var projectCards: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
                ForEach(sortedProjects) { project in
                    ProjectCard(project: project, store: store) {
                        if let onOpenProject {
                            onOpenProject(project)
                        }
                        selectedNode = project
                    }
                    .focusRing(isFocused: focusedProjectID == project.id)
                    .id(project.id)
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - List View

    private var projectList: some View {
        List {
            ForEach(sortedProjects) { node in
                let connections = store.connectedNodes(for: node.id).count
                let tasks = store.children(of: node.id, linkType: .belongsTo).filter { $0.type == .task }
                let completedTasks = tasks.filter { $0.status == .completed }.count

                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: node.pinned ? "folder.fill" : "folder")
                        .foregroundStyle(Theme.Colors.typeColor(.project))
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.title)
                            .font(Theme.Fonts.headline)

                        HStack(spacing: Theme.Spacing.sm) {
                            if !tasks.isEmpty {
                                HStack(spacing: 4) {
                                    ProgressView(value: Double(completedTasks), total: Double(tasks.count))
                                        .frame(width: 40)
                                        .controlSize(.mini)
                                    Text("\(completedTasks)/\(tasks.count)")
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text("\(connections) items")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        ConfidenceBadge(value: node.confidence)
                        RelevanceBar(value: node.relevance).frame(width: 40, height: 3)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedNode = node }
            }
            .onDelete { offsets in
                for index in offsets {
                    try? store.deleteNode(id: sortedProjects[index].id)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: MindNode
    let store: NodeStore
    let onTap: () -> Void
    @State private var isHovered = false

    private var tasks: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
    }
    private var openTasks: Int { tasks.filter { $0.status != .completed }.count }
    private var completedTasks: Int { tasks.filter { $0.status == .completed }.count }
    private var notes: Int { store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .note }.count }
    private var connections: Int { store.connectedNodes(for: project.id).count }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Accent bar at top
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.typeColor(.project).opacity(0.3))
                    .frame(height: 2)
            }

            // Header
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: project.pinned ? "folder.fill" : "folder")
                    .foregroundStyle(Theme.Colors.typeColor(.project))
                Text(project.title)
                    .font(Theme.Fonts.headline)
                    .lineLimit(1)
                Spacer()
                if project.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                RelevanceDot(value: project.relevance)
            }

            // Body preview
            if !project.body.isEmpty {
                Text(project.body)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Progress bar
            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(completedTasks), total: Double(tasks.count))
                        .tint(Theme.Colors.accent)
                    HStack {
                        Text("\(completedTasks)/\(tasks.count) tasks")
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if openTasks > 0 {
                            Text("\(openTasks) open")
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            // Stats row
            HStack(spacing: Theme.Spacing.md) {
                if notes > 0 {
                    Label("\(notes)", systemImage: "doc.text")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.secondary)
                }
                Label("\(connections)", systemImage: "link")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(project.updatedAt, style: .relative)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .spatialCard(
            shadow: isHovered ? Theme.Shadow.elevated : Theme.Shadow.card,
            radius: Theme.Radius.card
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(project.pinned ? Theme.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Relevance Dot

struct RelevanceDot: View {
    let value: Double
    var body: some View {
        Circle()
            .fill(Theme.Colors.relevance(value))
            .frame(width: 6, height: 6)
    }
}
