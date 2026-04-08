import SwiftUI

/// The main screen. Answers: "What should I know right now?"
/// Shows curated, relevance-ranked cards — not everything.
struct TodayView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Current main project
                if let project = mainProject {
                    sectionHeader("Main Project", icon: "folder.fill")
                    NodeCard(node: project, selectedNode: $selectedNode)
                }

                // Today's tasks
                let tasks = openTasks
                if !tasks.isEmpty {
                    sectionHeader("Tasks", icon: "checklist")
                    ForEach(tasks) { task in
                        TaskRow(task: task, selectedNode: $selectedNode)
                    }
                }

                // Recent notes
                let notes = recentNotes
                if !notes.isEmpty {
                    sectionHeader("Recent Notes", icon: "note.text")
                    ForEach(notes.prefix(5)) { note in
                        NodeCard(node: note, selectedNode: $selectedNode)
                    }
                }

                // Important people/events
                let important = importantPeopleAndEvents
                if !important.isEmpty {
                    sectionHeader("People & Events", icon: "person.crop.circle")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 8) {
                        ForEach(important) { node in
                            NodeCard(node: node, selectedNode: $selectedNode)
                        }
                    }
                }

                // Needs clarification
                let uncertain = store.uncertainNodes(limit: 3)
                if !uncertain.isEmpty {
                    sectionHeader("Needs Your Input", icon: "questionmark.app")
                    ForEach(uncertain) { node in
                        ClarificationCard(node: node, selectedNode: $selectedNode)
                    }
                }

                // Empty state
                if store.nodes.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Today")
    }

    // MARK: - Computed sections

    private var mainProject: MindNode? {
        store.activeNodes(ofType: .project).first
    }

    private var openTasks: [MindNode] {
        store.activeNodes(ofType: .task).prefix(8).map { $0 }
    }

    private var recentNotes: [MindNode] {
        store.nodes(ofType: .note).prefix(5).map { $0 }
    }

    private var importantPeopleAndEvents: [MindNode] {
        let people = store.activeNodes(ofType: .person).filter { $0.relevance > 0.4 }.prefix(3)
        let events = store.activeNodes(ofType: .event).filter { $0.relevance > 0.4 }.prefix(3)
        return (people + events).sorted { $0.relevance > $1.relevance }
    }

    // MARK: - UI

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
            Text(title).font(.headline)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Your mind is empty")
                .font(.title2.bold())
            Text("Use Quick Add or drop files to start building your brain.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
