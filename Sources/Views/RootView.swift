import SwiftUI

/// Root view: sidebar + detail.
/// Clean navigation following Apple HIG — max 2 levels, SF Symbols, grouped.
struct RootView: View {
    @Environment(NodeStore.self) private var store
    @State private var selectedScreen: Screen = .today
    @State private var selectedNode: MindNode?
    @State private var showInspector = false
    @State private var searchText = ""
    @State private var navigateToProject: MindNode?
    
    /// Global search results across all nodes — uses FTS5
    private var searchResults: [MindNode] {
        guard !searchText.isEmpty else { return [] }
        return store.search(searchText)
    }

    enum Screen: String, CaseIterable, Identifiable, Hashable {
        case today = "Today"
        case chat = "Chat"
        case projects = "Projects"
        case notes = "Notes"
        case tasks = "Tasks"
        case timeline = "Timeline"
        case people = "People"
        case sources = "Sources"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .today: "square.grid.2x2"
            case .chat: "brain.head.profile"
            case .projects: "folder"
            case .notes: "doc.text"
            case .tasks: "checklist"
            case .timeline: "clock"
            case .people: "person.2"
            case .sources: "link"
            }
        }
        
        /// Group for sidebar sections
        var group: String {
            switch self {
            case .today, .chat: "Home"
            case .projects, .notes, .tasks: "Organize"
            case .timeline, .people, .sources: "Browse"
            }
        }

        /// Keyboard shortcut — Cmd+1 through Cmd+8
        var keyEquivalent: KeyEquivalent? {
            switch self {
            case .today: "1"
            case .chat: "2"
            case .projects: "3"
            case .notes: "4"
            case .tasks: "5"
            case .timeline: "6"
            case .people: "7"
            case .sources: "8"
            }
        }
    }
    
    /// Screens grouped by section
    private var groupedScreens: [(String, [Screen])] {
        let allScreens: [Screen] = [.today, .chat, .projects, .notes, .tasks, .timeline, .people, .sources]
        let groups = Dictionary(grouping: allScreens) { $0.group }
        return [("Home", groups["Home"] ?? []),
                ("Organize", groups["Organize"] ?? []),
                ("Browse", groups["Browse"] ?? [])]
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if !searchText.isEmpty {
                searchResultsView
            } else {
                detailView
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search your brain...")
        .inspector(isPresented: $showInspector) {
            if let node = selectedNode {
                InspectorPanel(node: node)
            } else {
                inspectorEmptyState
            }
        }
        .onChange(of: selectedNode) { _, newNode in
            showInspector = newNode != nil
            // Track access — preference memory
            if var node = newNode {
                node.lastAccessedAt = Date()
                node.accessCount += 1
                try? store.insertNode(node)
            }
        }
        .onChange(of: selectedScreen) { _, _ in
            navigateToProject = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { selectedScreen = .today } label: {
                    Image(systemName: "plus.circle")
                }
                .controlSize(.small)
                .keyboardShortcut("n", modifiers: .command)
                .help("Quick Add (⌘N)")

                Button { showInspector.toggle() } label: {
                    Image(systemName: "sidebar.right")
                }
                .controlSize(.small)
                .keyboardShortcut("i", modifiers: .command)
                .help("Inspector (⌘I)")
            }
        }
        .navigationTitle("")
    }

    // MARK: - Sidebar

    /// Count badge for sidebar items
    private func screenCount(_ screen: Screen) -> Int {
        switch screen {
        case .today: return store.todayNodes().count
        case .chat: return 0
        case .projects: return store.activeNodes(ofType: .project).count
        case .notes: return store.nodes(ofType: .note).count
        case .tasks: return store.nodes(ofType: .task).filter { $0.status != .completed }.count
        case .timeline: return store.recentNodes(days: 7).count
        case .people: return store.nodes(ofType: .person).count
        case .sources: return store.nodes(ofType: .source).count
        }
    }

    private var sidebar: some View {
        List(selection: $selectedScreen) {
            ForEach(groupedScreens, id: \.0) { groupName, screens in
                Section(groupName) {
                    ForEach(screens) { screen in
                        Label {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(screen.rawValue)
                                Spacer()
                                let count = screenCount(screen)
                                if count > 0 {
                                    Text("\(count)")
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        } icon: {
                            Image(systemName: screen.icon)
                                .foregroundStyle(selectedScreen == screen ? Theme.Colors.accent : .secondary)
                        }
                        .tag(screen)
                        .keyboardShortcut(screen.keyEquivalent ?? "0", modifiers: .command)
                    }
                }
            }

            // Active projects inline
            let projects = store.activeNodes(ofType: .project)
                .sorted { ($0.pinned ? 1 : 0) + $0.relevance > ($1.pinned ? 1 : 0) + $1.relevance }
                .prefix(5)

            if !projects.isEmpty {
                Section("Projects") {
                    ForEach(Array(projects)) { project in
                        let tasks = store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
                        let openTasks = tasks.filter { $0.status != .completed }.count

                        Label {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(project.title)
                                    .lineLimit(1)
                                Spacer()
                                if openTasks > 0 {
                                    Text("\(openTasks)")
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        } icon: {
                            Image(systemName: project.pinned ? "folder.fill" : "folder")
                                .foregroundStyle(Theme.Colors.typeColor(.project))
                        }
                        .tag(Screen.projects)
                        .onTapGesture {
                            selectedScreen = .projects
                            withAnimation { navigateToProject = project }
                        }
                    }
                }
            }

            // Recent section — quick access to last-touched items
            let recentItems = store.recentNodes(days: 3, limit: 5)
            if !recentItems.isEmpty {
                Section("Recent") {
                    ForEach(recentItems) { node in
                        Label {
                            Text(node.title)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: node.type.sfIcon)
                                .foregroundStyle(Theme.Colors.typeColor(node.type))
                        }
                        .tag(selectedScreen) // keep current screen selected
                        .onTapGesture {
                            selectedNode = node
                            showInspector = true
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MindPalantir")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        if let project = navigateToProject {
            VStack(alignment: .leading, spacing: 0) {
                // Back navigation
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        withAnimation { navigateToProject = nil }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)

                Divider()

                ProjectDetailView(project: project, selectedNode: $selectedNode)
            }
            .id(project.id)
        } else {
            switch selectedScreen {
            case .today: TodayView(selectedNode: $selectedNode, onOpenProject: { project in
                withAnimation { navigateToProject = project }
            })
            case .chat: ChatView(selectedNode: $selectedNode, focusedProject: navigateToProject)
            case .projects: ProjectListView(selectedNode: $selectedNode, onOpenProject: { project in
                withAnimation { navigateToProject = project }
            })
            case .notes: NodeListView(type: .note, selectedNode: $selectedNode)
            case .tasks: NodeListView(type: .task, selectedNode: $selectedNode)
            case .timeline: TimelineView(selectedNode: $selectedNode)
            case .people: NodeListView(type: .person, selectedNode: $selectedNode)
            case .sources: NodeListView(type: .source, selectedNode: $selectedNode)
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("\(searchResults.count) results")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            Divider()
            
            // Results list
            List(searchResults) { node in
                SearchResultRow(node: node, selectedNode: $selectedNode)
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Inspector Empty State
    
    private var inspectorEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sidebar.right")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Select an item")
                .font(Theme.Fonts.headline)
                .foregroundStyle(.secondary)
            Text("Click any card to inspect it")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let node: MindNode
    @Binding var selectedNode: MindNode?
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: node.type.sfIcon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.typeColor(node.type))

            VStack(alignment: .leading, spacing: 2) {
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
                    Text(node.type.rawValue.capitalized)
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(Theme.Colors.typeColor(node.type))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(node.updatedAt, style: .relative)
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Circle()
                .fill(Theme.Colors.relevance(node.relevance))
                .frame(width: 6, height: 6)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = node }
    }
}
