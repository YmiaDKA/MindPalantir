import SwiftUI

// MARK: - Milestone Progress Bar

/// Segmented progress bar showing project progress through milestones.
/// Each segment is a milestone — filled if completed, outlined if not.
/// Shows completion ratio as text and visually.
struct MilestoneProgressBar: View {
    let milestones: [Milestone]

    private var completed: Int {
        milestones.filter(\.isCompleted).count
    }

    private var total: Int {
        milestones.count
    }

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        if milestones.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Label
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Milestones")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(completed) of \(total)")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                }

                // Segmented bar
                GeometryReader { geo in
                    let segWidth = total > 0
                        ? (geo.size.width - CGFloat(total - 1) * 3) / CGFloat(total)
                        : 0

                    HStack(spacing: 3) {
                        ForEach(milestones, id: \.id) { milestone in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(milestone.isCompleted
                                    ? segmentColor(for: milestone)
                                    : (isOverdue(milestone) ? Color.red.opacity(0.15) : Color.secondary.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(
                                            isOverdue(milestone) ? Color.red.opacity(0.4) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func segmentColor(for milestone: Milestone) -> Color {
        // Completed milestones get a gradient of greens/blues based on order
        let progress = Double(milestones.firstIndex(of: milestone) ?? 0) / max(1, Double(milestones.count - 1))
        return Color.green.opacity(0.3 + progress * 0.4)
    }

    private func isOverdue(_ milestone: Milestone) -> Bool {
        guard !milestone.isCompleted, let due = milestone.dueDate else { return false }
        return due < .now
    }
}

// MARK: - Milestone Timeline View

/// Visual timeline of milestones — a vertical "road" with dots and cards.
/// Inspired by Apple's timeline UI in Activity and Health.
struct MilestoneTimelineView: View {
    let milestones: [Milestone]
    let projectID: UUID
    @Environment(NodeStore.self) private var store
    @State private var editingMilestone: Milestone?
    @State private var showAddSheet = false

    var body: some View {
        if milestones.isEmpty {
            emptyTimeline
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Timeline entries
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    milestoneRow(milestone, index: index, isLast: index == milestones.count - 1)
                }

                // Add milestone button at end of timeline
                addMilestoneRow
            }
        }
    }

    // MARK: - Empty State

    private var emptyTimeline: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "flag")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                Text("Add milestones to track progress")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.accent)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAddSheet) {
            AddMilestoneSheet(projectID: projectID)
                .environment(store)
        }
    }

    // MARK: - Milestone Row

    private func milestoneRow(_ milestone: Milestone, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Timeline line + dot
            VStack(spacing: 0) {
                // Dot
                ZStack {
                    Circle()
                        .fill(milestone.isCompleted
                            ? Theme.Colors.accent
                            : (isOverdue(milestone) ? Color.red : Color.secondary.opacity(0.25))
                        )
                        .frame(width: 14, height: 14)

                    if milestone.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                // Connecting line (not for last item)
                if !isLast {
                    Rectangle()
                        .fill(milestone.isCompleted
                            ? Theme.Colors.accent.opacity(0.3)
                            : Color.secondary.opacity(0.1)
                        )
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }
            .frame(width: 14)
            .padding(.top, 2)

            // Content card
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .top) {
                    // Title
                    Text(milestone.title)
                        .font(milestone.isCompleted ? Theme.Fonts.body : Theme.Fonts.headline)
                        .foregroundStyle(milestone.isCompleted ? .secondary : .primary)
                        .strikethrough(milestone.isCompleted)

                    Spacer()

                    // Toggle button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            store.toggleMilestone(milestone.id, in: projectID)
                        }
                    } label: {
                        Image(systemName: milestone.isCompleted
                            ? "arrow.uturn.backward.circle"
                            : "checkmark.circle"
                        )
                        .font(.system(size: 16))
                        .foregroundStyle(milestone.isCompleted ? .secondary : Theme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                    .help(milestone.isCompleted ? "Mark incomplete" : "Mark complete")

                    // Edit button
                    Button { editingMilestone = milestone } label: {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Date
                if let due = milestone.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(due, style: .date)
                            .font(Theme.Fonts.caption)
                        if isOverdue(milestone) {
                            Text("overdue")
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.red.opacity(0.1), in: Capsule())
                        }
                        if let completed = milestone.completedDate {
                            Text("· completed \(completed, style: .date)")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(isOverdue(milestone) ? .red : .secondary)
                }

                // Note
                if !milestone.note.isEmpty {
                    Text(milestone.note)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, isLast ? 0 : Theme.Spacing.md)
        }
        .sheet(item: $editingMilestone) { ms in
            EditMilestoneSheet(milestone: ms, projectID: projectID)
                .environment(store)
        }
    }

    // MARK: - Add Button Row

    private var addMilestoneRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Dot (dashed circle)
            Circle()
                .strokeBorder(Theme.Colors.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                .frame(width: 14, height: 14)

            Button { showAddSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Add milestone")
                        .font(Theme.Fonts.caption)
                }
                .foregroundStyle(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Theme.Spacing.xs)
        .sheet(isPresented: $showAddSheet) {
            AddMilestoneSheet(projectID: projectID)
                .environment(store)
        }
    }

    // MARK: - Helpers

    private func isOverdue(_ milestone: Milestone) -> Bool {
        guard !milestone.isCompleted, let due = milestone.dueDate else { return false }
        return due < .now
    }
}

// MARK: - Add Milestone Sheet

struct AddMilestoneSheet: View {
    let projectID: UUID
    @Environment(NodeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date.now.addingTimeInterval(7 * 86400) // default: 1 week out
    @State private var note = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "flag.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Colors.accent)
                Text("New Milestone")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            // Title
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Title")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                TextField("Milestone name", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTitleFocused)
            }

            // Due date toggle + picker
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Toggle("Set due date", isOn: $hasDueDate)
                    .font(Theme.Fonts.caption)
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }

            // Note
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Note (optional)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                TextField("What does this milestone represent?", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            // Actions
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Milestone") {
                    let milestone = Milestone(
                        title: title.trimmingCharacters(in: .whitespaces),
                        dueDate: hasDueDate ? dueDate : nil,
                        note: note.trimmingCharacters(in: .whitespaces)
                    )
                    store.addMilestone(milestone, to: projectID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 400)
        .onAppear { isTitleFocused = true }
    }
}

// MARK: - Edit Milestone Sheet

struct EditMilestoneSheet: View {
    let milestone: Milestone
    let projectID: UUID
    @Environment(NodeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var note: String
    @State private var showDeleteConfirmation = false
    @FocusState private var isTitleFocused: Bool

    init(milestone: Milestone, projectID: UUID) {
        self.milestone = milestone
        self.projectID = projectID
        _title = State(initialValue: milestone.title)
        _hasDueDate = State(initialValue: milestone.dueDate != nil)
        _dueDate = State(initialValue: milestone.dueDate ?? .now)
        _note = State(initialValue: milestone.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "flag")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Colors.accent)
                Text("Edit Milestone")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            // Title
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Title")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                TextField("Milestone name", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTitleFocused)
            }

            // Due date
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Toggle("Set due date", isOn: $hasDueDate)
                    .font(Theme.Fonts.caption)
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }

            // Note
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Note")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                TextField("Optional note", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            Divider()

            // Actions
            HStack {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .confirmationDialog("Delete this milestone?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        store.deleteMilestone(milestone.id, from: projectID)
                        dismiss()
                    }
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    var updated = milestone
                    updated.title = title.trimmingCharacters(in: .whitespaces)
                    updated.dueDate = hasDueDate ? dueDate : nil
                    updated.note = note.trimmingCharacters(in: .whitespaces)
                    store.updateMilestone(updated, in: projectID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 400)
        .onAppear { isTitleFocused = true }
    }
}
