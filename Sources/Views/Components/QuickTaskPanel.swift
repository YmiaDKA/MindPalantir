import SwiftUI

/// Floating panel for creating a task from anywhere — Cmd+T.
/// Compact, focused, dismisses quickly. The capture muscle memory.
struct QuickTaskPanel: View {
    @Environment(NodeStore.self) private var store
    @Binding var isPresented: Bool
    @Binding var selectedNode: MindNode?

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedProject: MindNode?
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @FocusState private var titleFocused: Bool

    private var projects: [MindNode] {
        store.activeNodes(ofType: .project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checklist")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.accent)
                Text("New Task")
                    .font(Theme.Fonts.headline)
                Spacer()
                Text("⌘T")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            Divider()

            // Form
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Title
                TextField("What needs to get done?", text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.body)
                    .lineLimit(1...3)
                    .focused($titleFocused)
                    .onSubmit { createTask() }

                // Body (optional)
                if !bodyText.isEmpty || title.count > 3 {
                    TextField("Add details (optional)...", text: $bodyText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1...3)
                }

                // Project picker + due date row
                HStack(spacing: Theme.Spacing.sm) {
                    // Project selector
                    Menu {
                        Button("No Project") { selectedProject = nil }
                        Divider()
                        ForEach(projects) { project in
                            Button {
                                selectedProject = project
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                    Text(project.title)
                                    if selectedProject?.id == project.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedProject != nil ? "folder.fill" : "folder")
                                .font(.system(size: 11))
                            Text(selectedProject?.title ?? "Project")
                                .font(Theme.Fonts.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedProject != nil ? Theme.Colors.typeColor(.project) : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    }
                    .menuStyle(.borderlessButton)

                    // Due date toggle
                    Toggle(isOn: $hasDueDate) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            if hasDueDate {
                                Text("Due")
                                    .font(Theme.Fonts.caption)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                    if hasDueDate {
                        DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .font(Theme.Fonts.caption)
                    }

                    Spacer()

                    // Create button
                    Button { createTask() } label: {
                        Text("Create")
                            .font(Theme.Fonts.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(canCreate ? Theme.Colors.accent : Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                            .foregroundStyle(canCreate ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.cardLarge)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 24, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.cardLarge)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            // Auto-select first project if there's a clear focus
            if selectedProject == nil, let top = projects.first(where: { $0.pinned }) ?? projects.first {
                selectedProject = top
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                titleFocused = true
            }
        }
        .onExitCommand { isPresented = false }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func createTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = MindNode(
            type: .task,
            title: trimmed,
            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            relevance: 0.7,
            confidence: 0.9,
            sourceOrigin: "quick_task",
            dueDate: hasDueDate ? dueDate : nil
        )
        try? store.insertNode(task)

        // Link to project if selected
        if let project = selectedProject {
            let link = MindLink(sourceID: project.id, targetID: task.id, linkType: .belongsTo)
            try? store.insertLink(link)
        }

        // Select the new task so the inspector shows it
        selectedNode = task

        // Reset and dismiss
        title = ""
        bodyText = ""
        isPresented = false
    }
}
