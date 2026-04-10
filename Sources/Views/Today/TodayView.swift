import SwiftUI

/// The desk — a spatial canvas of what matters now.
/// Inspired by Muse: cards with depth, organic spacing, no grid feel.
/// Each card breathes. The canvas has weight.
///
/// Keyboard navigation:
///   ↑↓ or J/K   — move between cards
///   ←→ or H/L   — move within grids (projects, recent)
///   Tab/⇧Tab    — cycle between sections
///   Enter       — open/select focused item
///   Escape      — clear focus, then deselect node
///   Space       — toggle task completion (when task focused)
struct TodayView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    var onOpenProject: ((MindNode) -> Void)? = nil
    
    // Keyboard navigation — unified state
    @State private var nav = NavigationState()
    
    /// Navigable sections for Tab cycling
    private var navigableSections: [NavigableSection] {
        var sections: [NavigableSection] = []
        
        if focusProject != nil {
            sections.append(NavigableSection(id: "focus", items: [
                NavigableItem(id: "focus-card", section: "focus")
            ]))
        }
        if !openTasks.isEmpty {
            sections.append(NavigableSection(id: "tasks", items: openTasks.map {
                NavigableItem(id: "task-\($0.id.uuidString)", section: "tasks")
            }))
        }
        if !otherProjects.isEmpty {
            sections.append(NavigableSection(id: "projects", items: otherProjects.map {
                NavigableItem(id: "project-\($0.id.uuidString)", section: "projects")
            }))
        }
        if !recentActivity.isEmpty {
            sections.append(NavigableSection(id: "recent", items: recentActivity.map {
                NavigableItem(id: "recent-\($0.id.uuidString)", section: "recent")
            }))
        }
        return sections
    }
    
    /// Flat list of all navigable items (for linear up/down)
    private var allNavigableItems: [NavigableItem] {
        navigableSections.flatMap { $0.items }
    }
    
    private var focusProject: MindNode? {
        store.activeNodes(ofType: .project)
            .filter { $0.pinned || $0.relevance > 0.7 }
            .sorted { ($0.pinned ? 1 : 0) + $0.relevance > ($1.pinned ? 1 : 0) + $1.relevance }
            .first
    }
    
    private var openTasks: [MindNode] {
        store.activeNodes(ofType: .task)
            .filter { $0.status != .completed }
            .sorted { $0.relevance > $1.relevance }
            .prefix(5)
            .map { $0 }
    }
    
    private var recentActivity: [MindNode] {
        store.recentNodes(days: 3, limit: 6)
    }

    private var taskCount: Int {
        store.activeNodes(ofType: .task).filter { $0.status != .completed }.count
    }

    private var relevantPeople: [MindNode] {
        guard let project = focusProject else {
            return store.activeNodes(ofType: .person).prefix(3).map { $0 }
        }
        let connected = store.connectedNodes(for: project.id).filter { $0.type == .person }
        return connected.isEmpty ? store.activeNodes(ofType: .person).prefix(3).map { $0 } : connected
    }

    private var upcomingEvents: [MindNode] {
        let now = Date.now
        let week = now.addingTimeInterval(7 * 86400)
        return store.nodes(ofType: .event)
            .filter { guard let d = $0.dueDate else { return false }; return d >= now && d <= week }
            .sorted { ($0.dueDate ?? .now) < ($1.dueDate ?? .now) }
            .prefix(3)
            .map { $0 }
    }

    private var needsClarification: [MindNode] {
        store.uncertainNodes(limit: 3)
    }

    private var otherProjects: [MindNode] {
        store.activeNodes(ofType: .project)
            .filter { $0.id != focusProject?.id }
            .sorted { $0.relevance > $1.relevance }
            .prefix(4)
            .map { $0 }
    }

    private var resurfacedItems: [MindNode] {
        let now = Date.now.timeIntervalSince1970
        return store.nodes.values
            .filter {
                guard $0.status == .active, !$0.pinned else { return false }
                let days = (now - $0.lastAccessedAt.timeIntervalSince1970) / 86400
                return days >= 7 && days <= 30 && $0.relevance >= 0.15
            }
            .sorted { $0.relevance > $1.relevance }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Quick add — floating at top
                    QuickAddBar(focusedProject: focusProject)
                        .padding(.horizontal, Theme.Spacing.xxl)
                        .padding(.top, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.md)

                    if focusProject == nil && openTasks.isEmpty && store.nodes.isEmpty {
                        emptyState
                    } else {
                        // The canvas
                        canvas
                            .padding(.horizontal, Theme.Spacing.xxl)
                            .padding(.bottom, Theme.Spacing.xxl)
                    }
                }
            }
            .onChange(of: nav.scrollTargetID) { _, targetID in
                if let targetID {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
        }
        .background(Theme.Colors.windowBackground)
        // Arrow keys (↑↓) and Vim (j/k)
        .onKeyPress(.upArrow) { nav.moveFocus(direction: -1, in: allNavigableItems); return .handled }
        .onKeyPress(.downArrow) { nav.moveFocus(direction: 1, in: allNavigableItems); return .handled }
        .onKeyPress("j") { nav.moveFocus(direction: 1, in: allNavigableItems); return .handled }
        .onKeyPress("k") { nav.moveFocus(direction: -1, in: allNavigableItems); return .handled }
        // Horizontal (←→) and Vim (h/l) for grid sections
        .onKeyPress(.leftArrow) { nav.moveFocus(direction: -1, in: allNavigableItems); return .handled }
        .onKeyPress(.rightArrow) { nav.moveFocus(direction: 1, in: allNavigableItems); return .handled }
        .onKeyPress("h") { nav.moveFocus(direction: -1, in: allNavigableItems); return .handled }
        .onKeyPress("l") { nav.moveFocus(direction: 1, in: allNavigableItems); return .handled }
        // Tab: cycle between sections (Shift-Tab not distinguishable in SwiftUI onKeyPress)
        .onKeyPress(.tab) { nav.cycleSection(direction: 1, sections: navigableSections); return .handled }
        // Enter: activate focused item
        .onKeyPress(.return) { activateFocusedItem(); return .handled }
        // Space: toggle task completion when task focused
        .onKeyPress(.space) { toggleFocusedTask(); return .handled }
        // Escape: clear focus first, then deselect
        .onKeyPress(.escape) {
            if nav.focusedItemID != nil {
                nav.clearFocus()
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Keyboard Actions
    
    private func activateFocusedItem() {
        guard let focusedID = nav.focusedItemID else { return }
        
        if focusedID == "focus-card", let project = focusProject {
            if let onOpenProject { onOpenProject(project) }
            else { selectedNode = project }
        } else if focusedID.hasPrefix("task-") {
            let taskID = String(focusedID.dropFirst(5))
            if let uuid = UUID(uuidString: taskID),
               let task = store.nodes[uuid] {
                selectedNode = task
            }
        } else if focusedID.hasPrefix("project-") {
            let projectID = String(focusedID.dropFirst(8))
            if let uuid = UUID(uuidString: projectID),
               let project = store.nodes[uuid] {
                if let onOpenProject { onOpenProject(project) }
                else { selectedNode = project }
            }
        } else if focusedID.hasPrefix("recent-") {
            let nodeID = String(focusedID.dropFirst(7))
            if let uuid = UUID(uuidString: nodeID),
               let node = store.nodes[uuid] {
                selectedNode = node
            }
        }
    }
    
    /// Toggle completion of the currently focused task (Space key).
    private func toggleFocusedTask() {
        guard let focusedID = nav.focusedItemID, focusedID.hasPrefix("task-") else { return }
        let taskID = String(focusedID.dropFirst(5))
        guard let uuid = UUID(uuidString: taskID), var task = store.nodes[uuid] else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            task.status = task.status == .completed ? .active : .completed
            task.updatedAt = .now
            try? store.insertNode(task)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer().frame(height: 80)
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.accent.opacity(0.3))
            VStack(spacing: Theme.Spacing.sm) {
                Text("Your desk is empty")
                    .font(Theme.Fonts.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Use the Quick Add bar above to capture\nyour first project, task, or note.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: Theme.Spacing.md) {
                quickStartButton(icon: "folder", label: "New Project", type: .project)
                quickStartButton(icon: "checklist", label: "New Task", type: .task)
                quickStartButton(icon: "doc.text", label: "New Note", type: .note)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func quickStartButton(icon: String, label: String, type: NodeType) -> some View {
        Button {
            let node = MindNode(type: type, title: label, sourceOrigin: "quick_add")
            try? store.insertNode(node)
        } label: {
            Label(label, systemImage: icon)
                .font(Theme.Fonts.caption)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .foregroundStyle(Theme.Colors.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Canvas

    private var canvas: some View {
        // Muse-like layout: main card prominent, supporting cards flow around it.
        // No rigid grid — cards have organic spacing and varied sizes.
        HStack(alignment: .top, spacing: Theme.Spacing.xl) {
            // LEFT — the main workspace
            mainWorkspace
                .frame(maxWidth: .infinity, alignment: .leading)

            // RIGHT — supporting panels (compact)
            sidePanels
                .frame(width: 280)
        }
    }

    // MARK: - Main Workspace (left)

    private var mainWorkspace: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            // Focus: the hero card — big, breathing, takes space
            if let project = focusProject {
                SpatialFocusCard(project: project, store: store, selectedNode: $selectedNode, onOpenProject: onOpenProject)
                    .focusRing(isFocused: nav.focusedItemID == "focus-card")
                    .id("focus-card")
            }

            // Tasks — inline, not in a separate panel
            if !openTasks.isEmpty {
                taskBoard
            }

            // Other projects — as a flowing row of cards
            if !otherProjects.isEmpty {
                projectBoard
            }

            // Recent — scattered chips
            if !recentActivity.isEmpty {
                recentBoard
            }
        }
    }

    // MARK: - Side Panels (right)

    private var sidePanels: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            // Events
            if !upcomingEvents.isEmpty {
                SidePanel(title: "Upcoming", icon: "calendar") {
                    ForEach(upcomingEvents) { event in
                        eventRow(event)
                    }
                }
            }

            // People
            if !relevantPeople.isEmpty {
                SidePanel(title: "People", icon: "person.2") {
                    ForEach(relevantPeople.prefix(3)) { person in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.purple.opacity(0.5))
                            Text(person.title)
                                .font(Theme.Fonts.body)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNode = person }
                    }
                }
            }

            // Needs attention
            if !needsClarification.isEmpty {
                SidePanel(title: "Needs Attention", icon: "exclamationmark.triangle", accent: .orange) {
                    ForEach(needsClarification) { node in
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(node.title)
                                .font(Theme.Fonts.body)
                                .lineLimit(1)
                            Spacer()
                            ConfidenceBadge(value: node.confidence)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNode = node }
                    }
                }
            }

            // Resurfacing
            if !resurfacedItems.isEmpty {
                SidePanel(title: "Resurfacing", icon: "arrow.clockwise", accent: .orange.opacity(0.7)) {
                    ForEach(resurfacedItems) { node in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: node.type.sfIcon)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.typeColor(node.type))
                            Text(node.title)
                                .font(Theme.Fonts.caption)
                                .lineLimit(1)
                            Spacer()
                            Circle()
                                .fill(Theme.Colors.relevance(node.relevance))
                                .frame(width: 4, height: 4)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNode = node }
                    }
                }
            }
        }
    }

    // MARK: - Task Board

    private var taskBoard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Tasks")
                    .font(Theme.Fonts.sectionTitle)
                    .foregroundStyle(.primary)
                Text("\(openTasks.count)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                
                Spacer()
                
                if nav.focusedItemID?.hasPrefix("task-") == true {
                    KeyboardHintsBar(hints: [("↑↓", "nav"), ("↵", "open"), ("␣", "done")])
                }
            }

            VStack(spacing: 1) {
                ForEach(openTasks) { task in
                    let itemID = "task-\(task.id.uuidString)"
                    SpatialTaskRow(task: task, selectedNode: $selectedNode)
                        .focusRing(isFocused: nav.focusedItemID == itemID)
                        .id(itemID)
                }
            }
            .spatialCard()
        }
    }

    // MARK: - Project Board

    private var projectBoard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Other Projects")
                    .font(Theme.Fonts.sectionTitle)
                    .foregroundStyle(.primary)
                Spacer()
                if nav.focusedItemID?.hasPrefix("project-") == true {
                    KeyboardHintsBar(hints: [("↑↓", "nav"), ("↵", "open")])
                }
            }

            // Flowing grid — not rigid
            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(otherProjects) { project in
                    let itemID = "project-\(project.id.uuidString)"
                    SpatialProjectChip(project: project, store: store) {
                        if let onOpenProject { onOpenProject(project) }
                        else { selectedNode = project }
                    }
                    .focusRing(isFocused: nav.focusedItemID == itemID)
                    .id(itemID)
                }
            }
        }
    }

    // MARK: - Recent Board

    private var recentBoard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recent")
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(.primary)

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(recentActivity) { node in
                    let itemID = "recent-\(node.id.uuidString)"
                    SpatialRecentCard(node: node, selectedNode: $selectedNode)
                        .focusRing(isFocused: nav.focusedItemID == itemID)
                        .id(itemID)
                }
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(_ event: MindNode) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(Theme.Fonts.body)
                    .lineLimit(1)
                if let due = event.dueDate {
                    Text(due, style: .relative)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = event }
    }
}

// MARK: - Side Panel (compact card)

struct SidePanel<Content: View>: View {
    let title: String
    let icon: String
    var accent: Color = .secondary
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(accent)
                Text(title)
                    .font(Theme.Fonts.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                content
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spatialCard(shadow: Theme.Shadow.card)
    }
}

// MARK: - Spatial Focus Card (hero — the big one)

struct SpatialFocusCard: View {
    let project: MindNode
    let store: NodeStore
    @Binding var selectedNode: MindNode?
    var onOpenProject: ((MindNode) -> Void)? = nil
    @State private var isHovered = false

    private var tasks: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
    }
    private var completedTasks: [MindNode] {
        tasks.filter { $0.status == .completed }
    }
    private var connections: Int {
        store.linksFor(nodeID: project.id).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Title — big, bold, prominent
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Colors.typeColor(.project))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(project.title)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(.primary)

                    if !project.body.isEmpty {
                        Text(project.body)
                            .font(Theme.Fonts.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer()

                if project.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Stats — minimal, non-intrusive
            HStack(spacing: Theme.Spacing.lg) {
                if !tasks.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView(value: Double(completedTasks.count), total: Double(tasks.count))
                            .frame(width: 60)
                            .tint(Theme.Colors.accent)
                        Text("\(completedTasks.count)/\(tasks.count) tasks")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Label("\(connections)", systemImage: "link")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(project.status.rawValue.capitalized)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spatialCard(shadow: isHovered ? Theme.Shadow.elevated : Theme.Shadow.hero, radius: Theme.Radius.cardLarge)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.cardLarge)
                .strokeBorder(Theme.Colors.accent.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.cardLarge))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture {
            if let onOpenProject { onOpenProject(project) }
            else { selectedNode = project }
        }
    }
}

// MARK: - Spatial Task Row

struct SpatialTaskRow: View {
    @Environment(NodeStore.self) private var store
    let task: MindNode
    @Binding var selectedNode: MindNode?

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button { toggleComplete() } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(task.status == .completed ? .green : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(Theme.Fonts.body)
                    .strikethrough(task.status == .completed)
                if let due = task.dueDate {
                    Text(due, style: .relative)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(due < Date() ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                }
            }

            Spacer()

            // Parent project hint
            if let project = parentProject {
                Text(project.title)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.5))
                    .lineLimit(1)
            }

            Circle()
                .fill(Theme.Colors.relevance(task.relevance))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = task }
        .draggable(task.id.uuidString) {
            // Drag preview
            HStack(spacing: 8) {
                Image(systemName: task.type.sfIcon)
                    .foregroundStyle(Theme.Colors.typeColor(.task))
                Text(task.title)
                    .font(Theme.Fonts.caption)
                    .lineLimit(1)
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var parentProject: MindNode? {
        store.links.values
            .filter { $0.targetID == task.id && $0.linkType == .belongsTo }
            .compactMap { store.nodes[$0.sourceID] }
            .first { $0.type == .project }
    }

    private func toggleComplete() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            var updated = task
            updated.status = task.status == .completed ? .active : .completed
            updated.updatedAt = .now
            try? store.insertNode(updated)
        }
    }
}

// MARK: - Spatial Project Chip

struct SpatialProjectChip: View {
    let project: MindNode
    let store: NodeStore
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var isDropTarget = false

    private var tasks: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
    }
    private var completed: Int { tasks.filter { $0.status == .completed }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.typeColor(.project))
                Text(project.title)
                    .font(Theme.Fonts.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            if !tasks.isEmpty {
                HStack(spacing: 4) {
                    ProgressView(value: Double(completed), total: Double(tasks.count))
                        .frame(width: 30)
                        .controlSize(.mini)
                    Text("\(completed)/\(tasks.count)")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.secondary)
                }
            } else if !project.body.isEmpty {
                Text(project.body)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .spatialCard(shadow: isHovered ? Theme.Shadow.elevated : Theme.Shadow.card, radius: Theme.Radius.chip)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture(perform: onTap)
        .dropDestination(for: String.self) { items, _ in
            guard let nodeIDString = items.first,
                  let nodeID = UUID(uuidString: nodeIDString) else { return false }
            // Create belongsTo link from project to dropped node
            if !store.linkExists(sourceID: project.id, targetID: nodeID, type: .belongsTo) {
                let link = MindLink(sourceID: project.id, targetID: nodeID, linkType: .belongsTo)
                try? store.insertLink(link)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.1)) {
                isDropTarget = targeted
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .strokeBorder(Theme.Colors.accent.opacity(isDropTarget ? 0.5 : 0), lineWidth: 2)
        )
    }
}

// MARK: - Spatial Recent Card

struct SpatialRecentCard: View {
    @Environment(NodeStore.self) private var store
    let node: MindNode
    @Binding var selectedNode: MindNode?

    private var parentProject: MindNode? {
        store.links.values
            .filter { $0.targetID == node.id && $0.linkType == .belongsTo }
            .compactMap { store.nodes[$0.sourceID] }
            .first { $0.type == .project }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: node.type.sfIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.typeColor(node.type))
                Text(node.updatedAt, style: .relative)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }

            Text(node.title)
                .font(Theme.Fonts.caption)
                .lineLimit(2)

            if let project = parentProject {
                Text(project.title)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(minWidth: 100, maxWidth: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .onTapGesture { selectedNode = node }
    }
}

// MARK: - Flow Layout (organic spacing, not rigid grid)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(subviews: subviews, in: proposal.width ?? 0)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, in: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> (frames: [CGRect], height: CGFloat) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (frames, y + rowHeight)
    }
}
