import SwiftUI

/// Root view: sidebar + detail, the main app shell.
struct RootView: View {
    @Environment(NodeStore.self) private var store
    @State private var selectedScreen: Screen = .today
    @State private var selectedNode: MindNode?
    @State private var showInspector = false

    enum Screen: String, CaseIterable, Identifiable, Hashable {
        case today = "Today"
        case projects = "Projects"
        case notes = "Notes"
        case tasks = "Tasks"
        case people = "People"
        case events = "Events"
        case sources = "Sources"
        case timeline = "Timeline"
        case inbox = "Inbox"
        case clarification = "Clarification"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .today: "square.grid.2x2"
            case .projects: "folder"
            case .notes: "note.text"
            case .tasks: "checklist"
            case .people: "person.2"
            case .events: "calendar"
            case .sources: "link"
            case .timeline: "clock"
            case .inbox: "tray"
            case .clarification: "questionmark.app"
            }
        }
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
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Select an item")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Click any card to inspect it")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: selectedNode) { _, newNode in
            showInspector = newNode != nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                QuickAddBar()
                Button("Inspector", systemImage: "sidebar.right") {
                    showInspector.toggle()
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedScreen) {
            Section("Home") {
                Label(Screen.today.rawValue, systemImage: Screen.today.icon)
                    .tag(Screen.today)
            }

            Section("Content") {
                ForEach([Screen.projects, .notes, .tasks, .people, .events, .sources]) { s in
                    Label(s.rawValue, systemImage: s.icon).tag(s)
                }
            }

            Section("Review") {
                Label(Screen.timeline.rawValue, systemImage: Screen.timeline.icon)
                    .tag(Screen.timeline)
                Label(Screen.inbox.rawValue, systemImage: Screen.inbox.icon)
                    .tag(Screen.inbox)
                Label(Screen.clarification.rawValue, systemImage: Screen.clarification.icon)
                    .tag(Screen.clarification)
            }

            // Projects in sidebar
            if !store.activeNodes(ofType: .project).isEmpty {
                Section("Active Projects") {
                    ForEach(store.activeNodes(ofType: .project)) { p in
                        Label(p.title, systemImage: "folder.fill")
                            .tag(Screen.projects)
                            .onTapGesture(count: 2) {
                                selectedNode = p
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
        case .projects: ProjectListView(selectedNode: $selectedNode)
        case .notes: NodeListView(type: .note, selectedNode: $selectedNode)
        case .tasks: NodeListView(type: .task, selectedNode: $selectedNode)
        case .people: NodeListView(type: .person, selectedNode: $selectedNode)
        case .events: NodeListView(type: .event, selectedNode: $selectedNode)
        case .sources: NodeListView(type: .source, selectedNode: $selectedNode)
        case .timeline: TimelineView(selectedNode: $selectedNode)
        case .inbox: InboxView(selectedNode: $selectedNode)
        case .clarification: ClarificationView(selectedNode: $selectedNode)
        }
    }
}
