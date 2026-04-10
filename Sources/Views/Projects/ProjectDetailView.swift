import SwiftUI

/// Detail view for a single project — the workspace for one thing.
struct ProjectDetailView: View {
    @Environment(NodeStore.self) private var store
    let project: MindNode
    @Binding var selectedNode: MindNode?

    @State private var title: String
    @State private var bodyText: String

    init(project: MindNode, selectedNode: Binding<MindNode?>) {
        self.project = project
        self._selectedNode = selectedNode
        _title = State(initialValue: project.title)
        _bodyText = State(initialValue: project.body)
    }

    private var tasks: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
    }

    private var completedTasks: [MindNode] {
        tasks.filter { $0.status == .completed }
    }

    private var notes: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .note }
    }

    private var connections: [MindNode] {
        store.connectedNodes(for: project.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // Project header
                projectHeader

                // Tasks card
                if !tasks.isEmpty {
                    tasksCard
                }

                // Notes card
                if !notes.isEmpty {
                    notesCard
                }

                // Milestones
                milestonesCard

                // Connections summary
                if !connections.isEmpty {
                    connectionsCard
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .background(Theme.Colors.windowBackground)
    }

    // MARK: - Header

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.Colors.typeColor(.project))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    TextField("Project title", text: $title, axis: .vertical)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .onChange(of: title) { _, _ in saveProject() }

                    TextField("Add a description...", text: $bodyText, axis: .vertical)
                        .font(Theme.Fonts.body)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.secondary)
                        .lineLimit(1...5)
                        .onChange(of: bodyText) { _, _ in saveProject() }
                }

                Spacer()

                if project.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Progress
            if !tasks.isEmpty {
                HStack(spacing: Theme.Spacing.md) {
                    ProgressView(value: Double(completedTasks.count), total: Double(tasks.count))
                        .frame(width: 80)
                        .tint(Theme.Colors.accent)
                    Text("\(completedTasks.count)/\(tasks.count) tasks done")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.xl)
        .spatialCard(shadow: Theme.Shadow.hero, radius: Theme.Radius.cardLarge)
    }

    // MARK: - Tasks Card

    private var tasksCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Tasks")
                .font(Theme.Fonts.sectionTitle)

            VStack(spacing: 1) {
                ForEach(tasks) { task in
                    HStack(spacing: Theme.Spacing.sm) {
                        Button {
                            var updated = task
                            updated.status = updated.status == .completed ? .active : .completed
                            updated.updatedAt = .now
                            try? store.insertNode(updated)
                        } label: {
                            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(task.status == .completed ? .green : .secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)

                        Text(task.title)
                            .font(Theme.Fonts.body)
                            .strikethrough(task.status == .completed)
                            .lineLimit(1)

                        Spacer()

                        if let due = task.dueDate {
                            Text(due, style: .relative)
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(due < Date() ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = task }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .spatialCard()
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Notes")
                .font(Theme.Fonts.sectionTitle)

            ForEach(notes.prefix(5)) { note in
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.typeColor(.note))
                    Text(note.title)
                        .font(Theme.Fonts.body)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture { selectedNode = note }
            }
        }
        .padding(Theme.Spacing.lg)
        .spatialCard()
    }

    // MARK: - Milestones Card

    private var milestonesCard: some View {
        let milestones = store.milestones(for: project.id)
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Milestones")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                if !milestones.isEmpty {
                    let done = milestones.filter(\.isCompleted).count
                    Text("\(done)/\(milestones.count)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }

            MilestoneTimelineView(milestones: milestones, projectID: project.id)
        }
        .padding(Theme.Spacing.lg)
        .spatialCard()
    }

    // MARK: - Connections Card

    private var connectionsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Connections (\(connections.count))")
                .font(Theme.Fonts.sectionTitle)

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(connections.prefix(10)) { node in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.Colors.typeColor(node.type))
                            .frame(width: 5, height: 5)
                        Text(node.title)
                            .font(Theme.Fonts.caption)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = node }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .spatialCard()
    }

    // MARK: - Save

    private func saveProject() {
        var updated = project
        updated.title = title
        updated.body = bodyText
        updated.updatedAt = .now
        try? store.insertNode(updated)
    }
}
