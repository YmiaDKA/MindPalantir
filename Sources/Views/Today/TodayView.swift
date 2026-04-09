import SwiftUI

/// The "desk" — shows what matters NOW.
/// Two-column layout: focus area (left) + panels (right).
/// Desktop-like, not a list.
struct TodayView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    var onOpenProject: ((MindNode) -> Void)? = nil
    
    // What matters right now
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
            .prefix(6)
            .map { $0 }
    }
    
    private var recentActivity: [MindNode] {
        store.recentNodes(days: 3, limit: 6)
    }

    private var taskCount: Int {
        store.activeNodes(ofType: .task).filter { $0.status != .completed }.count
    }

    /// People connected to active projects
    private var relevantPeople: [MindNode] {
        guard let project = focusProject else {
            return store.activeNodes(ofType: .person).prefix(4).map { $0 }
        }
        let connected = store.connectedNodes(for: project.id).filter { $0.type == .person }
        if connected.isEmpty {
            return store.activeNodes(ofType: .person).prefix(4).map { $0 }
        }
        return connected
    }

    /// Upcoming events (next 7 days)
    private var upcomingEvents: [MindNode] {
        let now = Date.now
        let weekFromNow = now.addingTimeInterval(7 * 86400)
        return store.nodes(ofType: .event)
            .filter { node in
                guard let due = node.dueDate else { return false }
                return due >= now && due <= weekFromNow
            }
            .sorted { ($0.dueDate ?? .now) < ($1.dueDate ?? .now) }
            .prefix(4)
            .map { $0 }
    }

    /// Low-confidence items needing user attention
    private var needsClarification: [MindNode] {
        store.uncertainNodes(limit: 3)
    }

    /// Other active projects (excluding the focus project)
    private var otherProjects: [MindNode] {
        store.activeNodes(ofType: .project)
            .filter { $0.id != focusProject?.id }
            .sorted { $0.relevance > $1.relevance }
            .prefix(4)
            .map { $0 }
    }

    /// Resurfacing: items untouched 7-30 days but still relevant
    private var resurfacedItems: [MindNode] {
        let now = Date.now.timeIntervalSince1970
        return store.nodes.values
            .filter { node in
                guard node.status == .active && !node.pinned else { return false }
                let daysSince = (now - node.lastAccessedAt.timeIntervalSince1970) / 86400
                return daysSince >= 7 && daysSince <= 30 && node.relevance >= 0.15
            }
            .sorted { $0.relevance > $1.relevance }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Quick add — full width
                quickAdd
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.lg)

                Divider()
                    .padding(.horizontal, Theme.Spacing.xl)

                // Two-column layout
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    // LEFT: Focus area
                    leftColumn

                    // RIGHT: Panels
                    rightColumn
                        .frame(maxWidth: 340)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Left Column (Focus)

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            // Focus project
            if let project = focusProject {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    sectionLabel("FOCUS")
                    FocusCard(project: project, store: store, selectedNode: $selectedNode, onOpenProject: onOpenProject)
                }
            }

            // Other projects
            if !otherProjects.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    sectionLabel("OTHER PROJECTS")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.sm) {
                        ForEach(otherProjects) { project in
                            miniProjectCard(project)
                        }
                    }
                }
            }

            // Recent activity
            if !recentActivity.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    sectionLabel("RECENT")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.sm) {
                        ForEach(recentActivity) { node in
                            RecentChip(node: node, selectedNode: $selectedNode)
                        }
                    }
                }
            }

            // Resurfacing
            if !resurfacedItems.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        sectionLabel("RESURFACING")
                        Text("forgotten but relevant")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.tertiary)
                    }
                    VStack(spacing: 1) {
                        ForEach(resurfacedItems) { node in
                            resurfacingRow(node)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Right Column (Panels)

    private var rightColumn: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Tasks panel
            if !openTasks.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        sectionLabel("TASKS")
                        Spacer()
                        Text("\(openTasks.count)")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    VStack(spacing: 1) {
                        ForEach(openTasks) { task in
                            TaskRow(task: task, selectedNode: $selectedNode)
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            }

            // People panel
            if !relevantPeople.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    sectionLabel("PEOPLE")
                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(relevantPeople.prefix(4)) { person in
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.purple.opacity(0.6))
                                Text(person.title)
                                    .font(Theme.Fonts.body)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedNode = person }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            }

            // Events panel
            if !upcomingEvents.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    sectionLabel("UPCOMING")
                    VStack(spacing: 1) {
                        ForEach(upcomingEvents) { event in
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red.opacity(0.7))
                                VStack(alignment: .leading, spacing: 1) {
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
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedNode = event }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            }

            // Needs attention
            if !needsClarification.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        sectionLabel("NEEDS ATTENTION")
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("\(needsClarification.count)")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                    VStack(spacing: 1) {
                        ForEach(needsClarification) { node in
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.orange)
                                Text(node.title)
                                    .font(Theme.Fonts.body)
                                    .lineLimit(1)
                                Spacer()
                                ConfidenceBadge(value: node.confidence)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedNode = node }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            }
        }
    }

    // MARK: - Quick Add

    private var quickAdd: some View {
        QuickAddBar()
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }

    // MARK: - Mini Project Card

    private func miniProjectCard(_ project: MindNode) -> some View {
        let tasks = store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
        let completed = tasks.filter { $0.status == .completed }.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.typeColor(.project))
                Text(project.title)
                    .font(Theme.Fonts.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                RelevanceDot(value: project.relevance)
            }

            if !tasks.isEmpty {
                HStack(spacing: 4) {
                    ProgressView(value: Double(completed), total: Double(tasks.count))
                        .frame(width: 40)
                        .controlSize(.mini)
                    Text("\(completed)/\(tasks.count)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !project.body.isEmpty {
                Text(project.body)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else {
                Text("No tasks")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .contentShape(Rectangle())
        .onTapGesture {
            if let onOpenProject {
                onOpenProject(project)
            } else {
                selectedNode = project
            }
        }
    }

    // MARK: - Resurfacing Row

    private func resurfacingRow(_ node: MindNode) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: node.type.sfIcon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.typeColor(node.type))

            VStack(alignment: .leading, spacing: 1) {
                Text(node.title)
                    .font(Theme.Fonts.body)
                    .lineLimit(1)
                Text("last touched \(node.lastAccessedAt, style: .relative) ago")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Circle()
                .fill(Theme.Colors.relevance(node.relevance))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = node }
    }
}

// MARK: - Focus Card (hero project)

struct FocusCard: View {
    let project: MindNode
    let store: NodeStore
    @Binding var selectedNode: MindNode?
    var onOpenProject: ((MindNode) -> Void)? = nil
    
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
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Title row
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.typeColor(.project))
                
                Text(project.title)
                    .font(Theme.Fonts.largeTitle)
                    .lineLimit(2)
                
                Spacer()
                
                if project.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            
            // Description
            if !project.body.isEmpty {
                Text(project.body)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            // Stats row
            HStack(spacing: Theme.Spacing.lg) {
                // Progress
                if !tasks.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView(value: Double(completedTasks.count), total: Double(tasks.count))
                            .frame(width: 60)
                            .tint(Theme.Colors.relevance(project.relevance))
                        Text("\(completedTasks.count)/\(tasks.count)")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Connections
                Label("\(connections)", systemImage: "link")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                
                // Relevance
                HStack(spacing: 4) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(width: 40, height: 3)
                    Capsule()
                        .fill(Theme.Colors.relevance(project.relevance))
                        .frame(width: 40 * project.relevance, height: 3)
                }
                
                Spacer()
                
                Text(project.status.rawValue.capitalized)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.accent.opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let onOpenProject {
                onOpenProject(project)
            } else {
                selectedNode = project
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    @Environment(NodeStore.self) private var store
    let task: MindNode
    @Binding var selectedNode: MindNode?
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Checkbox
            Button { toggleComplete() } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(task.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // Title
            Text(task.title)
                .font(Theme.Fonts.body)
                .lineLimit(1)
                .strikethrough(task.status == .completed)
            
            Spacer()
            
            // Due date if present
            if let due = task.dueDate {
                Text(due, style: .relative)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(due < Date() ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
            }
            
            // Relevance dot
            Circle()
                .fill(Theme.Colors.relevance(task.relevance))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = task }
    }
    
    private func toggleComplete() {
        var updated = task
        updated.status = task.status == .completed ? .active : .completed
        updated.updatedAt = .now
        try? store.insertNode(updated)
    }
}

// MARK: - Recent Chip

struct RecentChip: View {
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
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: node.type.sfIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.typeColor(node.type))
                Text(node.updatedAt, style: .relative)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }
            
            Text(node.title)
                .font(Theme.Fonts.caption)
                .lineLimit(2)
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

            if let project = parentProject {
                Text(project.title)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = node }
    }
}
