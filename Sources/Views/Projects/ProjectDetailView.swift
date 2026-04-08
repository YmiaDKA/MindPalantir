import SwiftUI

/// Drill-down view for a single project.
/// Shows all linked items: tasks, notes, people, events, sources.
struct ProjectDetailView: View {
    @Environment(NodeStore.self) private var store
    let project: MindNode
    @Binding var selectedNode: MindNode?

    private var tasks: [MindNode] { store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task } }
    private var notes: [MindNode] { store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .note } }
    private var people: [MindNode] { store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .person } }
    private var events: [MindNode] { store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .event } }
    private var sources: [MindNode] { store.children(of: project.id, linkType: .fromSource) }
    private var allConnected: [MindNode] { store.connectedNodes(for: project.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project header
                projectHeader

                // Tasks
                if !tasks.isEmpty {
                    section("Tasks", icon: "checklist", nodes: tasks)
                }

                // Notes
                if !notes.isEmpty {
                    section("Notes", icon: "note.text", nodes: notes)
                }

                // People
                if !people.isEmpty {
                    section("People", icon: "person.2", nodes: people)
                }

                // Events
                if !events.isEmpty {
                    section("Events", icon: "calendar", nodes: events)
                }

                // Sources
                if !sources.isEmpty {
                    section("Sources", icon: "link", nodes: sources)
                }

                // All connected
                let otherConnected = allConnected.filter { node in
                    !tasks.contains(where: { $0.id == node.id }) &&
                    !notes.contains(where: { $0.id == node.id }) &&
                    !people.contains(where: { $0.id == node.id }) &&
                    !events.contains(where: { $0.id == node.id }) &&
                    !sources.contains(where: { $0.id == node.id })
                }
                if !otherConnected.isEmpty {
                    section("Related", icon: "link.circle", nodes: otherConnected)
                }

                // Quick add to project
                quickAddSection
            }
            .padding()
        }
        .navigationTitle(project.title)
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.type.icon).font(.largeTitle)
                VStack(alignment: .leading) {
                    Text(project.title).font(.title.bold())
                    HStack {
                        ConfidenceBadge(value: project.confidence)
                        Text(project.status.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Spacer()
                RelevanceBar(value: project.relevance).frame(width: 60, height: 6)
            }

            if !project.body.isEmpty {
                Text(project.body).font(.body).foregroundStyle(.secondary)
            }

            HStack {
                Text("\(allConnected.count) linked items")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Updated \(project.updatedAt, style: .relative)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func section(_ title: String, icon: String, nodes: [MindNode]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(title).font(.headline)
                Text("(\(nodes.count))").font(.caption).foregroundStyle(.secondary)
            }

            ForEach(nodes) { node in
                HStack {
                    Text(node.type.icon)
                    VStack(alignment: .leading) {
                        Text(node.title).font(.subheadline).lineLimit(1)
                        if !node.body.isEmpty {
                            Text(node.body).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    if node.type == .task {
                        Image(systemName: node.status == .completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(node.status == .completed ? .green : .secondary)
                    }
                    ConfidenceBadge(value: node.confidence)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                .onTapGesture { selectedNode = node }
            }
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add to Project").font(.headline)
            HStack {
                ForEach([NodeType.task, .note, .person, .event, .source], id: \.self) { type in
                    Button {
                        addLinkedNode(type: type)
                    } label: {
                        Label(type.rawValue.capitalized, systemImage: type.sfIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(.regularMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
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
