import SwiftUI

/// Floating panel for creating a new note from a template — Cmd+Shift+N.
/// Inspired by Notion's template picker: quick selection, pre-filled structure.
/// The goal is zero-friction capture with structure already in place.

struct NoteTemplate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let body: String
    let relevance: Double

    static let all: [NoteTemplate] = [
        .meetingNotes,
        .dailyJournal,
        .projectSpec,
        .researchNotes,
        .bookNotes,
        .oneOnOne,
        .retrospective,
        .blank,
    ]

    static let meetingNotes = NoteTemplate(
        name: "Meeting Notes",
        icon: "person.3",
        body: """
        ## Attendees
        - 

        ## Agenda
        1. 

        ## Discussion


        ## Action Items
        - [ ] 

        ## Decisions
        - 
        """,
        relevance: 0.8
    )

    static let dailyJournal = NoteTemplate(
        name: "Daily Journal",
        icon: "sunrise",
        body: """
        ## Morning Intentions
        - 

        ## Log


        ## Gratitude
        - 

        ## End of Day Reflection
        - What went well: 
        - What to improve: 
        - Tomorrow's focus: 
        """,
        relevance: 0.7
    )

    static let projectSpec = NoteTemplate(
        name: "Project Spec",
        icon: "doc.text.magnifyingglass",
        body: """
        ## Problem Statement


        ## Goals
        1. 

        ## Non-Goals
        - 

        ## Approach


        ## Open Questions
        - [ ] 

        ## Timeline
        - 
        """,
        relevance: 0.75
    )

    static let researchNotes = NoteTemplate(
        name: "Research Notes",
        icon: "magnifyingglass",
        body: """
        ## Source
        - URL: 
        - Author: 
        - Date: 

        ## Key Takeaways
        1. 

        ## Quotes
        > 

        ## My Thoughts


        ## Related
        - 
        """,
        relevance: 0.6
    )

    static let bookNotes = NoteTemplate(
        name: "Book Notes",
        icon: "book",
        body: """
        ## Book Info
        - Title: 
        - Author: 
        - Started: 

        ## Key Ideas
        1. 

        ## Favorite Quotes
        > 

        ## Chapter Notes


        ## Rating & Review
        - Rating: /5
        - Would recommend: 
        """,
        relevance: 0.5
    )

    static let oneOnOne = NoteTemplate(
        name: "1:1 Notes",
        icon: "person.2",
        body: """
        ## Their Updates
        - 

        ## My Updates
        - 

        ## Blockers
        - [ ] 

        ## Feedback
        - 

        ## Follow-ups
        - [ ] 
        """,
        relevance: 0.65
    )

    static let retrospective = NoteTemplate(
        name: "Retrospective",
        icon: "arrow.counterclockwise",
        body: """
        ## What Went Well
        - 

        ## What Didn't Go Well
        - 

        ## What We Learned
        - 

        ## Action Items
        - [ ] 
        """,
        relevance: 0.55
    )

    static let blank = NoteTemplate(
        name: "Blank Note",
        icon: "doc",
        body: "",
        relevance: 0.4
    )
}

struct TemplateNotePanel: View {
    @Environment(NodeStore.self) private var store
    @Binding var isPresented: Bool
    @Binding var selectedNode: MindNode?

    @State private var selectedTemplate: NoteTemplate?
    @State private var title = ""
    @State private var selectedProject: MindNode?
    @FocusState private var titleFocused: Bool

    private var projects: [MindNode] {
        store.activeNodes(ofType: .project)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: Theme.Spacing.sm)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "doc.text.badge.plus")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.accent)
                Text("New Note")
                    .font(Theme.Fonts.headline)
                Spacer()
                Text("⌘⇧N")
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

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Template grid
                Text("Template")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    ForEach(NoteTemplate.all) { template in
                        templateCard(template)
                    }
                }

                // Title field (shown after template selected)
                if selectedTemplate != nil {
                    Divider()

                    TextField("Note title...", text: $title, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(Theme.Fonts.body)
                        .lineLimit(1...3)
                        .focused($titleFocused)
                        .onSubmit { createNote() }

                    // Project picker
                    HStack(spacing: Theme.Spacing.sm) {
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
                                Text(selectedProject?.title ?? "Link to Project")
                                    .font(Theme.Fonts.caption)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(selectedProject != nil ? Theme.Colors.typeColor(.project) : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                        }
                        .menuStyle(.borderlessButton)

                        Spacer()

                        Button { createNote() } label: {
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
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .frame(width: 460)
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
            // Auto-select a relevant project
            if selectedProject == nil, let top = projects.first(where: { $0.pinned }) ?? projects.first {
                selectedProject = top
            }
        }
        .onExitCommand { isPresented = false }
    }

    private func templateCard(_ template: NoteTemplate) -> some View {
        let isSelected = selectedTemplate?.id == template.id
        return VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: template.icon)
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Theme.Colors.accent : .secondary)
            Text(template.name)
                .font(Theme.Fonts.tiny)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .fill(isSelected ? Theme.Colors.accent.opacity(0.1) : Color.secondary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .strokeBorder(isSelected ? Theme.Colors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .onTapGesture {
            selectedTemplate = template
            if title.isEmpty {
                title = template.name
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                titleFocused = true
            }
        }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedTemplate != nil
    }

    private func createNote() {
        guard let template = selectedTemplate else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let note = MindNode(
            type: .note,
            title: trimmed,
            body: template.body,
            relevance: template.relevance,
            confidence: 0.9,
            sourceOrigin: "template_\(template.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
            metadata: ["template": template.name]
        )
        try? store.insertNode(note)

        // Link to project if selected
        if let project = selectedProject {
            let link = MindLink(sourceID: project.id, targetID: note.id, linkType: .belongsTo)
            try? store.insertLink(link)
        }

        // Select the new note so the inspector shows it
        selectedNode = note

        // Dismiss
        isPresented = false
    }
}
