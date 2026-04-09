import SwiftUI

/// The "desk" — shows what matters NOW.
/// Inspired by Things 3: one focus, minimal chrome, no clutter.
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
            .prefix(5)
            .map { $0 }
    }
    
    private var recentActivity: [MindNode] {
        store.recentNodes(days: 3, limit: 8)
    }

    private var taskCount: Int {
        store.activeNodes(ofType: .task).filter { $0.status != .completed }.count
    }

    /// People connected to active projects — who matters now
    private var relevantPeople: [MindNode] {
        guard let project = focusProject else {
            return store.activeNodes(ofType: .person).prefix(3).map { $0 }
        }
        let connected = store.connectedNodes(for: project.id).filter { $0.type == .person }
        if connected.isEmpty {
            return store.activeNodes(ofType: .person).prefix(3).map { $0 }
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
            .prefix(3)
            .map { $0 }
    }

    /// Low-confidence items needing user attention
    private var needsClarification: [MindNode] {
        store.uncertainNodes(limit: 3)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // Quick add at top
                quickAdd

                // Focus: one project in detail
                if let project = focusProject {
                    focusSection(project)
                }

                // Tasks: compact list
                if !openTasks.isEmpty {
                    tasksSection
                }

                // People: who matters now
                if !relevantPeople.isEmpty {
                    peopleSection
                }

                // Events: upcoming
                if !upcomingEvents.isEmpty {
                    eventsSection
                }

                // Recent: timeline strip
                if !recentActivity.isEmpty {
                    recentSection
                }

                // Needs clarification
                if !needsClarification.isEmpty {
                    clarificationSection
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Theme.Spacing.md) {
                    Text("\(store.nodes.count) nodes")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                    if taskCount > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(taskCount) tasks")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Add
    
    private var quickAdd: some View {
        QuickAddBar()
            .frame(maxWidth: 400)
    }
    
    // MARK: - Focus Section
    
    private func focusSection(_ project: MindNode) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Section label
            Text("FOCUS")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)
            
            // Hero card
            FocusCard(project: project, store: store, selectedNode: $selectedNode, onOpenProject: onOpenProject)
        }
    }
    
    // MARK: - Tasks Section
    
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("TASKS")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                
                Text("\(openTasks.count)")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                
                Spacer()
            }
            
            VStack(spacing: 1) {
                ForEach(openTasks) { task in
                    TaskRow(task: task, selectedNode: $selectedNode)
                }
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }
    
    // MARK: - People Section

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("PEOPLE")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)

            HStack(spacing: Theme.Spacing.md) {
                ForEach(relevantPeople.prefix(4)) { person in
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.purple.opacity(0.6))
                        Text(person.title)
                            .font(Theme.Fonts.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = person }
                }
            }
        }
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("UPCOMING")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)

            VStack(spacing: 1) {
                ForEach(upcomingEvents) { event in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(.red.opacity(0.7))

                        Text(event.title)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)

                        Spacer()

                        if let due = event.dueDate {
                            Text(due, style: .relative)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.tertiary)
                        }
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

    // MARK: - Clarification Section

    private var clarificationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("NEEDS ATTENTION")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.orange)
                    .tracking(1)

                Text("\(needsClarification.count)")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.orange.opacity(0.15), in: Capsule())

                Spacer()
            }

            VStack(spacing: 1) {
                ForEach(needsClarification) { node in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13))
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

    // MARK: - Recent Section

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("RECENT")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(recentActivity) { node in
                        RecentChip(node: node, selectedNode: $selectedNode)
                    }
                }
            }
        }
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
    let node: MindNode
    @Binding var selectedNode: MindNode?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: node.type.sfIcon)
                    .font(.system(size: 11))
                Text(node.updatedAt, style: .relative)
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }
            
            Text(node.title)
                .font(Theme.Fonts.caption)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
        .padding(Theme.Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = node }
    }
}
