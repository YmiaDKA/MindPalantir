import SwiftUI

/// Detail view for a single project — the workspace for one thing.
/// Keyboard navigation: ↑↓/J/K between tasks, Space to toggle, Enter to select.
struct ProjectDetailView: View {
    @Environment(NodeStore.self) private var store
    let project: MindNode
    @Binding var selectedNode: MindNode?

    @State private var title: String
    @State private var bodyText: String
    @State private var taskOrder: [UUID] = []
    @State private var draggingTaskID: UUID?
    @State private var focusedTaskID: UUID?

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

    /// Tasks sorted by user-defined order (drag-and-drop), falling back to metadata then relevance.
    private var sortedTasks: [MindNode] {
        if taskOrder.isEmpty { return tasks }
        var ordered: [MindNode] = []
        var remaining = tasks
        for id in taskOrder {
            if let idx = remaining.firstIndex(where: { $0.id == id }) {
                ordered.append(remaining.remove(at: idx))
            }
        }
        ordered.append(contentsOf: remaining)
        return ordered
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

                // Mini graph canvas — visual map of this node's neighborhood
                miniGraphCard
            }
            .padding(Theme.Spacing.xxl)
        }
        .background(Theme.Colors.windowBackground)
        // Keyboard navigation for tasks
        .onKeyPress(.upArrow) { moveTaskFocus(direction: -1); return .handled }
        .onKeyPress(.downArrow) { moveTaskFocus(direction: 1); return .handled }
        .onKeyPress("k") { moveTaskFocus(direction: -1); return .handled }
        .onKeyPress("j") { moveTaskFocus(direction: 1); return .handled }
        .onKeyPress(.space) { toggleFocusedTask(); return .handled }
        .onKeyPress(.return) {
            if let id = focusedTaskID, let task = tasks.first(where: { $0.id == id }) {
                selectedNode = task
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if focusedTaskID != nil {
                focusedTaskID = nil
                return .handled
            }
            selectedNode = nil
            return .handled
        }
    }
    
    // MARK: - Keyboard Actions
    
    private func moveTaskFocus(direction: Int) {
        let ordered = sortedTasks
        guard !ordered.isEmpty else { return }
        
        if let currentID = focusedTaskID,
           let currentIndex = ordered.firstIndex(where: { $0.id == currentID }) {
            let newIndex = max(0, min(ordered.count - 1, currentIndex + direction))
            focusedTaskID = ordered[newIndex].id
        } else {
            focusedTaskID = direction > 0 ? ordered.first?.id : ordered.last?.id
        }
    }
    
    private func toggleFocusedTask() {
        guard let id = focusedTaskID, var task = tasks.first(where: { $0.id == id }) else { return }
        task.status = task.status == .completed ? .active : .completed
        task.updatedAt = .now
        try? store.insertNode(task)
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
            HStack(spacing: Theme.Spacing.sm) {
                Text("Tasks")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                if focusedTaskID != nil {
                    KeyboardHintsBar(hints: [("↑↓", "nav"), ("␣", "done"), ("↵", "open")])
                } else {
                    Text("drag to reorder")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(spacing: 1) {
                ForEach(sortedTasks) { task in
                    taskRow(task)
                        .focusRing(isFocused: focusedTaskID == task.id, style: .subtle)
                        .id(task.id)
                        .onDrag {
                            draggingTaskID = task.id
                            return NSItemProvider(object: task.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: TaskDropDelegate(
                                taskID: task.id,
                                draggingID: $draggingTaskID,
                                taskOrder: $taskOrder,
                                tasks: tasks,
                                saveOrder: saveTaskOrder
                            )
                        )
                }
            }
            .onAppear { loadTaskOrder() }
            .onChange(of: tasks.count) { _, _ in loadTaskOrder() }
        }
        .padding(Theme.Spacing.lg)
        .spatialCard()
    }

    private func taskRow(_ task: MindNode) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary.opacity(draggingTaskID == task.id ? 0.0 : 0.5))
                .frame(width: 12)

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
        .background(
            draggingTaskID == task.id
                ? Theme.Colors.accent.opacity(0.06)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = task }
    }

    // MARK: - Task Order Persistence

    private func loadTaskOrder() {
        guard let orderStr = project.metadata["taskOrder"] else {
            taskOrder = tasks.map(\.id)
            return
        }
        let ids = orderStr.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        // Include any new tasks not yet in order
        var ordered = ids.filter { id in tasks.contains(where: { $0.id == id }) }
        for task in tasks where !ordered.contains(task.id) {
            ordered.append(task.id)
        }
        taskOrder = ordered
    }

    private func saveTaskOrder() {
        var updated = project
        updated.metadata["taskOrder"] = taskOrder.map(\.uuidString).joined(separator: ",")
        updated.updatedAt = .now
        try? store.insertNode(updated)
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

    // MARK: - Mini Graph Card

    private var miniGraphCard: some View {
        MiniGraphCanvas(centerNode: project, selectedNode: $selectedNode)
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

// MARK: - Drop Delegate for Task Reordering

struct TaskDropDelegate: DropDelegate {
    let taskID: UUID
    @Binding var draggingID: UUID?
    @Binding var taskOrder: [UUID]
    let tasks: [MindNode]
    let saveOrder: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != taskID else { return }
        guard let fromIndex = taskOrder.firstIndex(of: draggingID),
              let toIndex = taskOrder.firstIndex(of: taskID) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            taskOrder.move(fromOffsets: IndexSet(integer: fromIndex),
                           toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        saveOrder()
        return true
    }
}
