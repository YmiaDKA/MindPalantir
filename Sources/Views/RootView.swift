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
    @State private var showQuickSwitcher = false
    @State private var showKeyboardHelp = false
    @State private var showCommandPalette = false
    @State private var showQuickTask = false
    @State private var focusMode = false
    @State private var preFocusShowInspector = false
    @StateObject private var toastManager = ToastManager()
    
    /// Global search results across all nodes — uses FTS5
    private var searchResults: [MindNode] {
        guard !searchText.isEmpty else { return [] }
        return store.search(searchText)
    }

    enum Screen: String, CaseIterable, Identifiable, Hashable {
        case today = "Today"
        case chat = "Chat"
        case projects = "Projects"
        case graph = "Graph"
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
            case .graph: "point.3.filled.connected.trianglepath.dotted"
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
            case .today, .chat, .graph: "Home"
            case .projects, .notes, .tasks: "Organize"
            case .timeline, .people, .sources: "Browse"
            }
        }

        /// Keyboard shortcut — Cmd+1 through Cmd+9
        var keyEquivalent: KeyEquivalent? {
            switch self {
            case .today: "1"
            case .chat: "2"
            case .projects: "3"
            case .graph: "4"
            case .notes: "5"
            case .tasks: "6"
            case .timeline: "7"
            case .people: "8"
            case .sources: "9"
            }
        }
    }

    /// Screens grouped by section
    private var groupedScreens: [(String, [Screen])] {
        let allScreens: [Screen] = [.today, .chat, .graph, .projects, .notes, .tasks, .timeline, .people, .sources]
        let groups = Dictionary(grouping: allScreens) { $0.group }
        return [("Home", groups["Home"] ?? []),
                ("Organize", groups["Organize"] ?? []),
                ("Browse", groups["Browse"] ?? [])]
    }

    var body: some View {
        if focusMode {
            focusModeView
        } else {
            normalView
        }
    }

    /// Focus Mode: just the detail, no sidebar or inspector.
    /// Inspired by "zen mode" in code editors — full attention on the content.
    private var focusModeView: some View {
        Group {
            if !searchText.isEmpty {
                searchResultsView
            } else {
                detailView
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    exitFocusMode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 11))
                        Text("Exit Focus")
                            .font(Theme.Fonts.caption)
                    }
                    .foregroundStyle(Theme.Colors.accent)
                }
                .keyboardShortcut(".", modifiers: .command)
                .help("Exit Focus Mode (⌘.)")
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Theme.Spacing.sm) {
                    Button { showQuickSwitcher = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .controlSize(.small)
                    .keyboardShortcut("k", modifiers: .command)
                    .help("Quick Switch (⌘K)")

                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("FocusQuickAdd"), object: nil)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .controlSize(.small)
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Quick Add (⌘N)")

                    Button { showQuickTask = true } label: {
                        Image(systemName: "checkmark.circle.badge.plus")
                    }
                    .controlSize(.small)
                    .help("Quick Task (⌘T)")
                }
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search your brain...")
        .overlay {
            if showQuickSwitcher {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showQuickSwitcher = false }
                    QuickSwitcher(
                        selectedNode: $selectedNode,
                        isPresented: $showQuickSwitcher
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showQuickSwitcher)
            }
            if showQuickTask {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { showQuickTask = false }
                    QuickTaskPanel(
                        isPresented: $showQuickTask,
                        selectedNode: $selectedNode
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showQuickTask)
            }
        }
        .onChange(of: selectedNode) { _, newNode in
            if var node = newNode {
                node.lastAccessedAt = Date()
                node.accessCount += 1
                try? store.insertNode(node)
                if showQuickSwitcher, node.type == .project {
                    selectedScreen = .projects
                    withAnimation { navigateToProject = node }
                    showQuickSwitcher = false
                }
            }
        }
        .toast(manager: toastManager)
        .environment(\.toastManager, toastManager)
        .background {
            Button("") { duplicateSelectedNode() }
                .keyboardShortcut("d", modifiers: .command)
                .opacity(0)
            Button("") { showQuickTask = true }
                .keyboardShortcut("t", modifiers: .command)
                .opacity(0)
        }
    }

    private var normalView: some View {
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
        .overlay {
            if showQuickSwitcher {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showQuickSwitcher = false }
                    QuickSwitcher(
                        selectedNode: $selectedNode,
                        isPresented: $showQuickSwitcher
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showQuickSwitcher)
            }
            if showKeyboardHelp {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { showKeyboardHelp = false }
                    KeyboardHelp(isPresented: $showKeyboardHelp)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showKeyboardHelp)
            }
            if showCommandPalette {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showCommandPalette = false }
                    CommandPalette(
                        selectedNode: $selectedNode,
                        isPresented: $showCommandPalette
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showCommandPalette)
            }
            if showQuickTask {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { showQuickTask = false }
                    QuickTaskPanel(
                        isPresented: $showQuickTask,
                        selectedNode: $selectedNode
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showQuickTask)
            }
        }
        .onChange(of: selectedNode) { _, newNode in
            showInspector = newNode != nil
            // Track access — preference memory
            if var node = newNode {
                node.lastAccessedAt = Date()
                node.accessCount += 1
                try? store.insertNode(node)
                // If quick switcher selected a project, navigate to it
                if showQuickSwitcher, node.type == .project {
                    selectedScreen = .projects
                    withAnimation { navigateToProject = node }
                    showQuickSwitcher = false
                }
            }
        }
        .onChange(of: selectedScreen) { _, _ in
            navigateToProject = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectNode"))) { notification in
            if let node = notification.object as? MindNode {
                selectedNode = node
                showInspector = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToScreen"))) { notification in
            if let screenName = notification.object as? String,
               let screen = Screen(rawValue: screenName.capitalized) {
                selectedScreen = screen
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowToast"))) { notification in
            if let info = notification.object as? [String: String],
               let message = info["message"] {
                let icon = info["icon"] ?? "checkmark.circle.fill"
                let styleStr = info["style"] ?? "success"
                let style: Toast.Style = switch styleStr {
                case "info": .info
                case "warning": .warning
                case "error": .error
                default: .success
                }
                toastManager.show(message, icon: icon, style: style)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleFocusMode"))) { _ in
            if focusMode { exitFocusMode() } else { enterFocusMode() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleInspector"))) { _ in
            showInspector.toggle()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Theme.Spacing.sm) {
                    Button { showQuickSwitcher = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .controlSize(.small)
                    .keyboardShortcut("k", modifiers: .command)
                    .help("Quick Switch (⌘K)")
                    .accessibilityLabel("Quick Switch")

                    Button {
                        selectedScreen = .today
                        NotificationCenter.default.post(name: NSNotification.Name("FocusQuickAdd"), object: nil)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .controlSize(.small)
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Quick Add (⌘N)")
                    .accessibilityLabel("Quick Add")

                    Button { showQuickTask = true } label: {
                        Image(systemName: "checkmark.circle.badge.plus")
                    }
                    .controlSize(.small)
                    .help("Quick Task (⌘T)")
                    .accessibilityLabel("Quick Task")

                    Button { showInspector.toggle() } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .controlSize(.small)
                    .keyboardShortcut("i", modifiers: .command)
                    .help("Inspector (⌘I)")
                    .accessibilityLabel("Inspector")

                    Button { showCommandPalette.toggle() } label: {
                        Image(systemName: "command")
                    }
                    .controlSize(.small)
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .help("Commands (⌘⇧P)")
                    .accessibilityLabel("Command Palette")

                    Button { enterFocusMode() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .controlSize(.small)
                    .keyboardShortcut(".", modifiers: .command)
                    .help("Focus Mode (⌘.)")
                    .accessibilityLabel("Focus Mode")

                    Button { showKeyboardHelp.toggle() } label: {
                        Image(systemName: "keyboard")
                    }
                    .controlSize(.small)
                    .keyboardShortcut("/", modifiers: .command)
                    .help("Shortcuts (⌘/)")
                    .accessibilityLabel("Keyboard Shortcuts")
                }
            }
        }
        .navigationTitle("")
        .toolbarRole(.automatic)
        .toast(manager: toastManager)
        .environment(\.toastManager, toastManager)
        .background {
            // Global keyboard shortcut: duplicate selected node
            Button("") { duplicateSelectedNode() }
                .keyboardShortcut("d", modifiers: .command)
                .opacity(0)
            // Global keyboard shortcut: quick task
            Button("") { showQuickTask = true }
                .keyboardShortcut("t", modifiers: .command)
                .opacity(0)
        }
    }

    // MARK: - Duplicate Node

    private func duplicateSelectedNode() {
        guard let node = selectedNode else { return }
        if let copy = try? store.duplicateNode(id: node.id) {
            selectedNode = copy
            toastManager.show("Duplicated \"\(node.title)\"", icon: "doc.on.doc")
        }
    }

    // MARK: - Focus Mode

    private func enterFocusMode() {
        preFocusShowInspector = showInspector
        withAnimation(.easeInOut(duration: 0.2)) {
            focusMode = true
            showInspector = false
        }
    }

    private func exitFocusMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            focusMode = false
            showInspector = preFocusShowInspector
        }
    }

    // MARK: - Sidebar

    // MARK: - Today Summary

    private var todaySummarySection: some View {
        let openTasks = store.activeNodes(ofType: .task).filter { $0.status != .completed }
        let overdueTasks = openTasks.filter { ($0.dueDate ?? .distantFuture) < Date() }
        let upcomingEvents = store.nodes(ofType: .event).filter {
            guard let d = $0.dueDate else { return false }
            return d >= Date() && d <= Date().addingTimeInterval(7 * 86400)
        }
        let pinnedProjects = store.activeNodes(ofType: .project).filter { $0.pinned }
        let uncertain = store.uncertainNodes(limit: 99)

        return Section("Today") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Top row: tasks + events
                HStack(spacing: Theme.Spacing.md) {
                    // Tasks
                    HStack(spacing: 5) {
                        Image(systemName: "checklist")
                            .font(.system(size: 11))
                            .foregroundStyle(openTasks.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Theme.Colors.typeColor(.task)))
                        Text("\(openTasks.count)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(openTasks.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                        Text("open")
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.chip)
                            .fill(openTasks.isEmpty ? Color.clear : Theme.Colors.typeColor(.task).opacity(0.06))
                    )

                    // Events
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(upcomingEvents.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Theme.Colors.typeColor(.event)))
                        Text("\(upcomingEvents.count)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(upcomingEvents.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                        Text("upcoming")
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.chip)
                            .fill(upcomingEvents.isEmpty ? Color.clear : Theme.Colors.typeColor(.event).opacity(0.06))
                    )

                    Spacer()
                }

                // Bottom row: warnings + pinned
                HStack(spacing: Theme.Spacing.md) {
                    if !overdueTasks.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                            Text("\(overdueTasks.count) overdue")
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    }

                    if !uncertain.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("\(uncertain.count) unclear")
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    }

                    if !pinnedProjects.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange.opacity(0.7))
                            Text("\(pinnedProjects.count) pinned")
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// Count badge for sidebar items
    private func screenCount(_ screen: Screen) -> Int {
        switch screen {
        case .today: return store.todayNodes().count
        case .chat: return 0
        case .projects: return store.activeNodes(ofType: .project).count
        case .graph: return store.nodes.count
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

            // Today Summary — at-a-glance dashboard
            todaySummarySection

            // Active projects inline — with relevance dots and pin indicators
            let projects = store.activeNodes(ofType: .project)
                .sorted { ($0.pinned ? 1 : 0) + $0.relevance > ($1.pinned ? 1 : 0) + $1.relevance }
                .prefix(5)

            if !projects.isEmpty {
                Section("Projects") {
                    ForEach(Array(projects)) { project in
                        let tasks = store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
                        let completedTasks = tasks.filter { $0.status == .completed }.count

                        Label {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(project.title)
                                    .lineLimit(1)
                                Spacer()
                                // Relevance dot
                                Circle()
                                    .fill(Theme.Colors.relevance(project.relevance))
                                    .frame(width: 5, height: 5)
                                if tasks.count > 0 {
                                    Text("\(completedTasks)/\(tasks.count)")
                                        .font(Theme.Fonts.tiny)
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

            // Recent section — with type colors and timestamps
            let recentItems = store.recentNodes(days: 3, limit: 5)
            if !recentItems.isEmpty {
                Section("Recent") {
                    ForEach(recentItems) { node in
                        Label {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(node.title)
                                    .lineLimit(1)
                                Spacer()
                                Text(node.updatedAt, style: .relative)
                                    .font(Theme.Fonts.tiny)
                                    .foregroundStyle(.tertiary)
                            }
                        } icon: {
                            Image(systemName: node.type.sfIcon)
                                .foregroundStyle(Theme.Colors.typeColor(node.type))
                        }
                        .tag(selectedScreen)
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
            case .graph: GraphView(selectedNode: $selectedNode)
            case .notes: NodeListView(type: .note, selectedNode: $selectedNode)
            case .tasks: NodeListView(type: .task, selectedNode: $selectedNode)
            case .timeline: TimelineView(selectedNode: $selectedNode)
            case .people: NodeListView(type: .person, selectedNode: $selectedNode)
            case .sources: NodeListView(type: .source, selectedNode: $selectedNode)
            }
        }
    }
    
    // MARK: - Search Results
    
    @State private var searchFilter: NodeType?
    
    private var filteredResults: [MindNode] {
        if let filter = searchFilter {
            return searchResults.filter { $0.type == filter }
        }
        return searchResults
    }
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with type filters
            HStack(spacing: Theme.Spacing.sm) {
                Text("\(filteredResults.count) results")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Type filter pills
                HStack(spacing: 4) {
                    filterPill(label: "All", isSelected: searchFilter == nil) {
                        searchFilter = nil
                    }
                    ForEach(NodeType.allCases, id: \.self) { type in
                        let count = searchResults.filter { $0.type == type }.count
                        if count > 0 {
                            filterPill(label: "\(type.rawValue) \(count)", isSelected: searchFilter == type) {
                                searchFilter = type
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            Divider()
            
            // Results list
            List(filteredResults) { node in
                SearchResultRow(node: node, selectedNode: $selectedNode)
            }
            .listStyle(.plain)
        }
    }
    
    private func filterPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Fonts.tiny)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isSelected ? Theme.Colors.accent.opacity(0.15) : Color.clear, in: Capsule())
                .foregroundStyle(isSelected ? Theme.Colors.accent : .secondary)
        }
        .buttonStyle(.plain)
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
