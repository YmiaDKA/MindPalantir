import SwiftUI

/// Root view: sidebar + detail.
/// Clean navigation following Apple HIG — max 2 levels, SF Symbols, grouped.
struct RootView: View {
    @Environment(NodeStore.self) private var store
    @State private var selectedScreen: Screen = .today
    @State private var selectedNode: MindNode?
    @State private var showInspector = false

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
            detailView
        }
        .inspector(isPresented: $showInspector) {
            if let node = selectedNode {
                InspectorPanel(node: node)
            } else {
                inspectorEmptyState
            }
        }
        .onChange(of: selectedNode) { _, newNode in
            showInspector = newNode != nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showInspector.toggle() } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("Inspector")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedScreen) {
            ForEach(groupedScreens, id: \.0) { groupName, screens in
                Section(groupName) {
                    ForEach(screens) { screen in
                        Label {
                            Text(screen.rawValue)
                        } icon: {
                            Image(systemName: screen.icon)
                        }
                        .tag(screen)
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
                        Label {
                            Text(project.title)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: project.pinned ? "folder.fill" : "folder")
                        }
                        .tag(Screen.projects)
                        .onTapGesture(count: 2) {
                            selectedNode = project
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
        switch selectedScreen {
        case .today: TodayView(selectedNode: $selectedNode)
        case .chat: ChatView(selectedNode: $selectedNode)
        case .projects: ProjectListView(selectedNode: $selectedNode)
        case .notes: NodeListView(type: .note, selectedNode: $selectedNode)
        case .tasks: NodeListView(type: .task, selectedNode: $selectedNode)
        case .timeline: TimelineView(selectedNode: $selectedNode)
        case .people: NodeListView(type: .person, selectedNode: $selectedNode)
        case .sources: NodeListView(type: .source, selectedNode: $selectedNode)
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
                .font(Theme.Font.cardTitle())
                .foregroundStyle(.secondary)
            Text("Click any card to inspect it")
                .font(Theme.Font.caption())
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
