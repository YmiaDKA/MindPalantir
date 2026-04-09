import SwiftUI

/// Card dashboard for a single project.
/// Each section is a self-contained card panel — feels like a living workspace, not a flat list.
struct ProjectDetailView: View {
    @Environment(NodeStore.self) private var store
    let project: MindNode
    @Binding var selectedNode: MindNode?

    // MARK: - Derived Data

    private var tasks: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
    }
    private var openTasks: [MindNode] {
        tasks.filter { $0.status != .completed }
            .sorted { $0.relevance > $1.relevance }
    }
    private var completedTasks: [MindNode] {
        tasks.filter { $0.status == .completed }
    }
    private var notes: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo)
            .filter { $0.type == .note }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    private var people: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .person }
    }
    private var events: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo)
            .filter { $0.type == .event }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    private var sources: [MindNode] {
        store.children(of: project.id, linkType: .fromSource)
    }
    private var allConnected: [MindNode] {
        store.connectedNodes(for: project.id)
    }
    private var recentActivity: [MindNode] {
        // Recent notes + tasks for this project (updated in last 14 days)
        let cutoff = Date.now.addingTimeInterval(-14 * 86400)
        return (notes + tasks)
            .filter { $0.updatedAt > cutoff }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(6)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // Overview card — always at top
                overviewCard

                // Dashboard grid: two columns on wider screens
                AdaptiveCardGrid {
                    // Tasks card
                    if !tasks.isEmpty {
                        tasksCard
                    }

                    // Activity card
                    if !recentActivity.isEmpty {
                        activityCard
                    }

                    // People card
                    if !people.isEmpty {
                        peopleCard
                    }

                    // Events card
                    if !events.isEmpty {
                        eventsCard
                    }

                    // Sources card
                    if !sources.isEmpty {
                        sourcesCard
                    }

                    // Quick add card
                    quickAddCard
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle(project.title)
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Title row
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Colors.typeColor(.project))

                Text(project.title)
                    .font(Theme.Fonts.largeTitle)
                    .lineLimit(2)

                Spacer()

                // Status pill
                Text(project.status.rawValue.capitalized)
                    .font(Theme.Fonts.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(statusColor)

                ConfidenceBadge(value: project.confidence)
            }

            // Description
            if !project.body.isEmpty {
                Text(project.body)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            // Progress bar (full width)
            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(completedTasks.count)/\(tasks.count) tasks")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(Double(completedTasks.count) / Double(tasks.count) * 100))%")
                            .font(Theme.Fonts.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule()
                                .fill(completedTasks.count == tasks.count ? .green : Theme.Colors.accent.opacity(0.6))
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                }
            }

            // Stats row
            HStack(spacing: Theme.Spacing.lg) {
                statLabel("\(allConnected.count)", icon: "link", label: "connected")
                statLabel("\(tasks.count)", icon: "checklist", label: "tasks")
                statLabel("\(notes.count)", icon: "note.text", label: "notes")
                statLabel("\(sources.count)", icon: "link", label: "sources")

                Spacer()

                Text("Updated \(project.updatedAt, style: .relative)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.accent.opacity(0.12), lineWidth: 1)
        )
    }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedTasks.count) / Double(tasks.count)
    }

    private var statusColor: Color {
        switch project.status {
        case .active: .green
        case .completed: .blue
        case .archived: .secondary
        case .draft: .orange
        case .waiting: .yellow
        }
    }

    private func statLabel(_ value: String, icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Tasks Card

    private var tasksCard: some View {
        DashboardCard(title: "Tasks", icon: "checklist", count: tasks.count) {
            VStack(spacing: 1) {
                // Show open tasks first, then up to 3 completed
                let displayTasks = openTasks + completedTasks.prefix(3)
                ForEach(displayTasks) { task in
                    taskRow(task)
                }

                if completedTasks.count > 3 {
                    Text("+ \(completedTasks.count - 3) more completed")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func taskRow(_ task: MindNode) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { toggleTask(task) } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(task.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(Theme.Fonts.body)
                .lineLimit(1)
                .strikethrough(task.status == .completed)
                .foregroundStyle(task.status == .completed ? .secondary : .primary)

            Spacer()

            if let due = task.dueDate {
                Text(due, style: .relative)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(due < Date() ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
            }

            Circle()
                .fill(Theme.Colors.relevance(task.relevance))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = task }
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        DashboardCard(title: "Recent Activity", icon: "clock", count: recentActivity.count) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(recentActivity) { node in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: node.type.sfIcon)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.typeColor(node.type))
                            .frame(width: 16)

                        Text(node.title)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)

                        Spacer()

                        Text(node.updatedAt, style: .relative)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = node }
                }
            }
        }
    }

    // MARK: - People Card

    private var peopleCard: some View {
        DashboardCard(title: "People", icon: "person.2", count: people.count) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(people) { person in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Colors.typeColor(.person))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(person.title)
                                .font(Theme.Fonts.body)
                                .lineLimit(1)
                            if !person.body.isEmpty {
                                Text(person.body)
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = person }
                }
            }
        }
    }

    // MARK: - Events Card

    private var eventsCard: some View {
        DashboardCard(title: "Events", icon: "calendar", count: events.count) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(events) { event in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.typeColor(.event))

                        Text(event.title)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)

                        Spacer()

                        if let due = event.dueDate {
                            Text(due, style: .relative)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(due < Date() ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                        }
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = event }
                }
            }
        }
    }

    // MARK: - Sources Card

    private var sourcesCard: some View {
        DashboardCard(title: "Sources", icon: "link", count: sources.count) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(sources) { source in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.typeColor(.source))

                        Text(source.title)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)

                        Spacer()

                        ConfidenceBadge(value: source.confidence)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = source }
                }
            }
        }
    }

    // MARK: - Quick Add Card

    private var quickAddCard: some View {
        DashboardCard(title: "Add", icon: "plus.circle", showCount: false) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach([NodeType.task, .note, .person, .event, .source], id: \.self) { type in
                    Button { addLinkedNode(type: type) } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: type.sfIcon)
                                .frame(width: 16)
                            Text(type.rawValue.capitalized)
                            Spacer()
                            Image(systemName: "plus")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .font(Theme.Fonts.body)
                        .padding(.vertical, 4)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleTask(_ node: MindNode) {
        var updated = node
        updated.status = node.status == .completed ? .active : .completed
        updated.updatedAt = .now
        try? store.insertNode(updated)
    }

    private func addLinkedNode(type: NodeType) {
        let node = MindNode(
            type: type,
            title: "New \(type.rawValue)",
            sourceOrigin: "project_add"
        )
        try? store.insertNode(node)

        let link = MindLink(
            sourceID: project.id,
            targetID: node.id,
            linkType: type == .source ? .fromSource : .belongsTo
        )
        try? store.insertLink(link)
    }
}

// MARK: - Dashboard Card (reusable panel)

struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    var count: Int = 0
    var showCount: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Card header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(.primary)
                if showCount {
                    Text("\(count)")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
            }

            content()
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }
}

// MARK: - Adaptive Card Grid

/// Two-column grid on wider views, single column on narrow.
/// Uses LazyVGrid so cards fill naturally.
struct AdaptiveCardGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: Theme.Spacing.md),
            GridItem(.flexible(), spacing: Theme.Spacing.md),
        ]
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            content()
        }
    }
}
