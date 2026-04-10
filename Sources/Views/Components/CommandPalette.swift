import SwiftUI

// MARK: - Command Palette 2.0
// Unified command palette + quick switcher. Cmd+Shift+P to open.
// Search nodes AND commands in one place. Context-aware actions.
// Arrow keys to navigate, Enter to execute, Escape to dismiss.
//
// Design: Three sections in results:
//   1. Contextual actions (if a node is selected)
//   2. Node search results (fuzzy matched)
//   3. Commands (filtered by query)
//
// Inspired by: VS Code Command Palette, Raycast, Linear, Obsidian.

struct CommandPalette: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    // MARK: - Palette Item Model

    enum PaletteItem: Identifiable {
        case node(MindNode)
        case command(Command)
        case action(NodeAction)

        var id: String {
            switch self {
            case .node(let node): "node-\(node.id)"
            case .command(let cmd): "cmd-\(cmd.id)"
            case .action(let action): "action-\(action.id)"
            }
        }
    }

    struct Command: Identifiable {
        let id = UUID()
        let icon: String
        let name: String
        let shortcut: String?
        let category: String
        let action: () -> Void
    }

    // MARK: - Node Actions (contextual)

    struct NodeAction: Identifiable {
        let id = UUID()
        let icon: String
        let name: String
        let shortcut: String?
        let action: () -> Void
    }

    // MARK: - Computed Results

    private var allItems: [PaletteItem] {
        var items: [PaletteItem] = []
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()

        // Section 1: Contextual actions for selected node
        if let node = selectedNode {
            items.append(contentsOf: contextualActions(for: node)
                .filter { trimmed.isEmpty || $0.name.lowercased().contains(trimmed) }
                .map { .action($0) })
        }

        // Section 2: Node search results
        if !trimmed.isEmpty {
            let nodeResults = store.search(query, limit: 8)
            items.append(contentsOf: nodeResults.map { .node($0) })
        } else if selectedNode == nil {
            // Show recent + pinned when empty and no selection
            let pinned = store.nodes.values.filter { $0.pinned }
                .sorted { $0.updatedAt > $1.updatedAt }
            let recent = store.recentNodes(days: 7, limit: 5)
            let combined = Array((pinned + recent).uniqued().prefix(6))
            items.append(contentsOf: combined.map { .node($0) })
        }

        // Section 3: Commands
        let filteredCommands = commands.filter {
            trimmed.isEmpty ||
            $0.name.lowercased().contains(trimmed) ||
            $0.category.lowercased().contains(trimmed)
        }
        items.append(contentsOf: filteredCommands.map { .command($0) })

        return items
    }

    // MARK: - Contextual Actions

    private func contextualActions(for node: MindNode) -> [NodeAction] {
        var actions: [NodeAction] = []

        // Universal actions
        actions.append(NodeAction(
            icon: node.pinned ? "pin.slash" : "pin",
            name: node.pinned ? "Unpin" : "Pin \"\(node.title)\"",
            shortcut: nil
        ) {
            var updated = node
            updated.pinned.toggle()
            updated.updatedAt = .now
            try? store.insertNode(updated)
            selectedNode = updated
            toast(node.pinned ? "Unpinned" : "Pinned", icon: "pin")
        })

        actions.append(NodeAction(
            icon: "doc.on.doc",
            name: "Duplicate \"\(node.title)\"",
            shortcut: "⌘D"
        ) {
            if let copy = try? store.duplicateNode(id: node.id) {
                selectedNode = copy
                toast("Duplicated", icon: "doc.on.doc")
            }
        })

        actions.append(NodeAction(
            icon: "arrow.triangle.branch",
            name: "Show Related Nodes",
            shortcut: nil
        ) {
            let connected = store.connectedNodes(for: node.id)
            if connected.isEmpty {
                toast("No connections", icon: "sparkles", style: .info)
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "graph")
                toast("Found \(connected.count) related nodes", icon: "sparkles")
            }
        })

        // Type-specific actions
        switch node.type {
        case .task:
            actions.append(NodeAction(
                icon: node.status == .completed ? "arrow.uturn.backward.circle" : "checkmark.circle.fill",
                name: node.status == .completed ? "Reopen Task" : "Complete Task",
                shortcut: nil
            ) {
                var updated = node
                updated.status = updated.status == .completed ? .active : .completed
                updated.updatedAt = .now
                try? store.insertNode(updated)
                selectedNode = updated
                toast(updated.status == .completed ? "Completed" : "Reopened", icon: "checkmark.circle")
            })

        case .project:
            actions.append(NodeAction(
                icon: "checkmark.circle.badge.plus",
                name: "Add Task to Project",
                shortcut: nil
            ) {
                let task = MindNode(type: .task, title: "New Task", sourceOrigin: "command_palette")
                try? store.insertNode(task)
                let link = MindLink(sourceID: task.id, targetID: node.id, linkType: .belongsTo)
                try? store.insertLink(link)
                selectedNode = task
                toast("Task created in project", icon: "checkmark.circle.badge.plus")
            })

            actions.append(NodeAction(
                icon: "note.text.badge.plus",
                name: "Add Note to Project",
                shortcut: nil
            ) {
                let note = MindNode(type: .note, title: "New Note", sourceOrigin: "command_palette")
                try? store.insertNode(note)
                let link = MindLink(sourceID: note.id, targetID: node.id, linkType: .belongsTo)
                try? store.insertLink(link)
                selectedNode = note
                toast("Note created in project", icon: "note.text.badge.plus")
            })

            actions.append(NodeAction(
                icon: "flag.badge.plus",
                name: "Add Milestone to Project",
                shortcut: nil
            ) {
                let milestone = Milestone(title: "New Milestone")
                store.addMilestone(milestone, to: node.id)
                toast("Milestone added", icon: "flag.badge.plus")
            })

        case .note:
            actions.append(NodeAction(
                icon: "arrow.triangle.merge",
                name: "Link to Project...",
                shortcut: nil
            ) {
                // Create a link to the most relevant active project
                let projects = store.activeNodes(ofType: .project)
                    .sorted { $0.relevance > $1.relevance }
                if let project = projects.first {
                    if !store.linkExists(sourceID: node.id, targetID: project.id, type: .belongsTo) {
                        let link = MindLink(sourceID: node.id, targetID: project.id, linkType: .belongsTo)
                        try? store.insertLink(link)
                        toast("Linked to \"\(project.title)\"", icon: "link")
                    } else {
                        toast("Already linked", icon: "link", style: .info)
                    }
                } else {
                    toast("No projects available", icon: "link", style: .warning)
                }
            })

        case .person:
            actions.append(NodeAction(
                icon: "person.crop.circle.badge.plus",
                name: "Find Mentions of \(node.title)",
                shortcut: nil
            ) {
                let backlinks = store.backlinks(for: node.id)
                if backlinks.isEmpty {
                    toast("No mentions found", icon: "person.crop.circle", style: .info)
                } else {
                    toast("Mentioned in \(backlinks.count) nodes", icon: "person.crop.circle")
                }
            })

        default:
            break
        }

        // Status change actions for non-completed nodes
        if node.status != .completed && node.type == .task {
            actions.append(NodeAction(
                icon: "clock.badge.exclamationmark",
                name: "Mark as Waiting",
                shortcut: nil
            ) {
                var updated = node
                updated.status = .waiting
                updated.updatedAt = .now
                try? store.insertNode(updated)
                selectedNode = updated
                toast("Marked as waiting", icon: "clock")
            })
        }

        // Archive action
        if node.status != .archived {
            actions.append(NodeAction(
                icon: "archivebox",
                name: "Archive",
                shortcut: nil
            ) {
                var updated = node
                updated.status = .archived
                updated.updatedAt = .now
                try? store.insertNode(updated)
                selectedNode = nil
                toast("Archived", icon: "archivebox")
            })
        }

        // Delete action (always last)
        actions.append(NodeAction(
            icon: "trash",
            name: "Delete \"\(node.title)\"",
            shortcut: "⌘⌫"
        ) {
            try? store.deleteNode(id: node.id)
            selectedNode = nil
            toast("Deleted", icon: "trash", style: .warning)
        })

        return actions
    }

    // MARK: - Global Commands

    private var commands: [Command] {
        [
            // Create
            Command(icon: "folder.badge.plus", name: "New Project", shortcut: nil, category: "Create") {
                let node = MindNode(type: .project, title: "New Project", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
                toast("Project created", icon: "folder.badge.plus")
            },
            Command(icon: "checkmark.circle.badge.plus", name: "New Task", shortcut: nil, category: "Create") {
                let node = MindNode(type: .task, title: "New Task", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
                toast("Task created", icon: "checkmark.circle.badge.plus")
            },
            Command(icon: "note.text.badge.plus", name: "New Note", shortcut: nil, category: "Create") {
                let node = MindNode(type: .note, title: "New Note", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
                toast("Note created", icon: "note.text.badge.plus")
            },
            Command(icon: "person.badge.plus", name: "New Person", shortcut: nil, category: "Create") {
                let node = MindNode(type: .person, title: "New Person", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
                toast("Person created", icon: "person.badge.plus")
            },
            Command(icon: "calendar.badge.plus", name: "New Event", shortcut: nil, category: "Create") {
                let node = MindNode(type: .event, title: "New Event", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
                toast("Event created", icon: "calendar.badge.plus")
            },

            // Navigate
            Command(icon: "square.grid.2x2", name: "Go to Today", shortcut: "⌘1", category: "Navigate") {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "today")
            },
            Command(icon: "folder", name: "Go to Projects", shortcut: "⌘3", category: "Navigate") {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "projects")
            },
            Command(icon: "point.3.filled.connected.trianglepath.dotted", name: "Go to Graph", shortcut: "⌘4", category: "Navigate") {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "graph")
            },
            Command(icon: "doc.text", name: "Go to Notes", shortcut: "⌘5", category: "Navigate") {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "notes")
            },
            Command(icon: "checklist", name: "Go to Tasks", shortcut: "⌘6", category: "Navigate") {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "tasks")
            },
            Command(icon: "clock", name: "Go to Timeline", shortcut: "⌘7", category: "Navigate") {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "timeline")
            },
            Command(icon: "person.2", name: "Go to People", shortcut: "⌘8", category: "Navigate") {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "people")
            },

            // Actions
            Command(icon: "arrow.up.left.and.arrow.down.right", name: "Toggle Focus Mode", shortcut: "⌘.", category: "Actions") {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleFocusMode"), object: nil)
            },
            Command(icon: "sidebar.right", name: "Toggle Inspector", shortcut: "⌘I", category: "Actions") {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleInspector"), object: nil)
            },

            // System
            Command(icon: "arrow.clockwise", name: "Rebuild Search Index", shortcut: nil, category: "System") {
                store.rebuildSearchIndex()
                toast("Search index rebuilt", icon: "arrow.clockwise")
            },
            Command(icon: "arrow.clockwise", name: "Decay Relevance Scores", shortcut: nil, category: "System") {
                store.decayRelevance()
                toast("Relevance decayed", icon: "arrow.clockwise")
            },
            Command(icon: "square.and.arrow.up", name: "Export All as JSON", shortcut: nil, category: "System") {
                exportNodes()
            },
        ]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            searchField

            Divider()

            // Results
            resultsList
        }
        .frame(width: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < allItems.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            executeSelected()
            return .handled
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "command")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField(selectedNode != nil ? "Search commands or type to act on selection..." : "Search nodes and commands...",
                      text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isSearchFocused)
                .onChange(of: query) { _, _ in
                    selectedIndex = 0
                }

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Result count
            Text("\(allItems.count)")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Results List

    private var resultsList: some View {
        Group {
            if allItems.isEmpty && !query.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 1) {
                            // Section: Contextual Actions
                            let actionItems = allItems.filter {
                                if case .action = $0 { return true }
                                return false
                            }
                            if !actionItems.isEmpty {
                                sectionHeader("ACTIONS")
                                ForEach(Array(actionItems.enumerated()), id: \.element.id) { _, item in
                                    paletteRow(item)
                                }
                            }

                            // Section: Node Results
                            let nodeItems = allItems.filter {
                                if case .node = $0 { return true }
                                return false
                            }
                            if !nodeItems.isEmpty {
                                sectionHeader(selectedNode != nil && query.isEmpty ? "BROWSE" : "NODES")
                                ForEach(Array(nodeItems.enumerated()), id: \.element.id) { _, item in
                                    paletteRow(item)
                                }
                            }

                            // Section: Commands
                            let cmdItems = allItems.filter {
                                if case .command = $0 { return true }
                                return false
                            }
                            if !cmdItems.isEmpty {
                                sectionHeader("COMMANDS")
                                ForEach(Array(cmdItems.enumerated()), id: \.element.id) { _, item in
                                    paletteRow(item)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 380)
                    .onChange(of: selectedIndex) { _, newIndex in
                        let item = allItems[safe: newIndex]
                        if let item {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No results for \"\(query)\"")
                .font(Theme.Fonts.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Fonts.tiny)
            .foregroundStyle(.tertiary)
            .tracking(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, 2)
    }

    // MARK: - Palette Row

    @ViewBuilder
    private func paletteRow(_ item: PaletteItem) -> some View {
        let globalIndex = allItems.firstIndex(where: { $0.id == item.id }) ?? 0
        let isSelected = globalIndex == selectedIndex

        Button {
            execute(item)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                rowIcon(for: item)
                    .frame(width: 20)

                // Content
                rowContent(for: item)

                Spacer()

                // Shortcut badge
                if let shortcut = rowShortcut(for: item) {
                    Text(shortcut)
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected
                ? Theme.Colors.accent.opacity(0.08)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
        .id(item.id)
    }

    @ViewBuilder
    private func rowIcon(for item: PaletteItem) -> some View {
        switch item {
        case .node(let node):
            Image(systemName: node.type.sfIcon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.typeColor(node.type))
        case .command(let cmd):
            Image(systemName: cmd.icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.accent)
        case .action(let action):
            Image(systemName: action.icon)
                .font(.system(size: 13))
                .foregroundStyle(action.icon == "trash" ? .red : Theme.Colors.accent)
        }
    }

    @ViewBuilder
    private func rowContent(for item: PaletteItem) -> some View {
        switch item {
        case .node(let node):
            VStack(alignment: .leading, spacing: 1) {
                Text(node.title)
                    .font(Theme.Fonts.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(node.type.rawValue.capitalized)
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(Theme.Colors.typeColor(node.type))

                    if node.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(node.updatedAt, style: .relative)
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    // Relevance dot
                    Circle()
                        .fill(Theme.Colors.relevance(node.relevance))
                        .frame(width: 5, height: 5)
                }
            }

        case .command(let cmd):
            VStack(alignment: .leading, spacing: 1) {
                Text(cmd.name)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.primary)

                Text(cmd.category)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }

        case .action(let action):
            Text(action.name)
                .font(Theme.Fonts.body)
                .foregroundStyle(action.icon == "trash" ? .red : .primary)
                .lineLimit(1)
        }
    }

    private func rowShortcut(for item: PaletteItem) -> String? {
        switch item {
        case .command(let cmd): cmd.shortcut
        case .action(let action): action.shortcut
        default: nil
        }
    }

    // MARK: - Execute

    private func executeSelected() {
        guard selectedIndex >= 0, selectedIndex < allItems.count else { return }
        execute(allItems[selectedIndex])
    }

    private func execute(_ item: PaletteItem) {
        switch item {
        case .node(let node):
            selectedNode = node
            // Touch the node
            var touched = node
            touched.lastAccessedAt = Date()
            touched.accessCount += 1
            try? store.insertNode(touched)
            // If it's a project, navigate to projects screen
            if node.type == .project {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToScreen"), object: "projects")
            }
            isPresented = false

        case .command(let cmd):
            cmd.action()
            isPresented = false

        case .action(let action):
            action.action()
            isPresented = false
        }
    }

    // MARK: - Toast

    private func toast(_ message: String, icon: String = "checkmark.circle.fill", style: Toast.Style = .success) {
        let styleStr: String
        switch style {
        case .success: styleStr = "success"
        case .info: styleStr = "info"
        case .warning: styleStr = "warning"
        case .error: styleStr = "error"
        }
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowToast"),
            object: ["message": message, "icon": icon, "style": styleStr]
        )
    }

    // MARK: - Export

    private func exportNodes() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Array(store.nodes.values)) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "mindpalantir-export.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
            toast("Exported \(store.nodes.count) nodes", icon: "square.and.arrow.up")
        }
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Array Dedup Extension

private extension Array where Element: Identifiable {
    func uniqued() -> [Element] {
        var seen: Set<Element.ID> = []
        return filter { seen.insert($0.id).inserted }
    }
}
