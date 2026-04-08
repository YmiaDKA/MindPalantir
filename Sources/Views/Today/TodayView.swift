import SwiftUI

/// The main desktop view — a living brain snapshot.
/// Cards are positioned in zones with visible connection lines.
/// Click to drill into projects/items like opening folders.
struct TodayView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @State private var expandedProject: MindNode?

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Connection lines behind everything
                    connectionLines

                    // Cards positioned on the canvas
                    VStack(alignment: .leading, spacing: 0) {
                        // Row 1: Main project + its children
                        HStack(alignment: .top, spacing: 16) {
                            // Main project card
                            if let project = mainProject {
                                ProjectCard(node: project, isExpanded: expandedProject?.id == project.id, selectedNode: $selectedNode, onExpand: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedProject = (expandedProject?.id == project.id) ? nil : project
                                    }
                                })
                                .frame(width: 280)

                                // Expanded children
                                if expandedProject?.id == project.id {
                                    expandedChildrenView(for: project)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }

                            Spacer()

                            // People & Events zone
                            VStack(alignment: .trailing, spacing: 8) {
                                ForEach(importantPeopleAndEvents.prefix(4)) { node in
                                    SmallCard(node: node, selectedNode: $selectedNode)
                                        .frame(width: 160)
                                }
                            }
                        }
                        .padding(.bottom, 20)

                        // Row 2: Active tasks + recent notes
                        HStack(alignment: .top, spacing: 16) {
                            // Tasks column
                            VStack(alignment: .leading, spacing: 6) {
                                sectionLabel("Active Tasks", count: openTasks.count)
                                ForEach(openTasks.prefix(6)) { task in
                                    TaskRow(task: task, selectedNode: $selectedNode)
                                }
                            }
                            .frame(width: 320)

                            Spacer()

                            // Recent notes column
                            VStack(alignment: .leading, spacing: 6) {
                                sectionLabel("Recent Notes", count: recentNotes.count)
                                ForEach(recentNotes.prefix(4)) { note in
                                    NoteCard(node: note, selectedNode: $selectedNode)
                                        .frame(width: 240)
                                }
                            }
                        }
                        .padding(.bottom, 20)

                        // Row 3: Other projects + clarification
                        HStack(alignment: .top, spacing: 16) {
                            // Other projects
                            let otherProjects = store.activeNodes(ofType: .project).filter { $0.id != mainProject?.id }
                            if !otherProjects.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionLabel("Other Projects", count: otherProjects.count)
                                    ForEach(otherProjects.prefix(4)) { project in
                                        ProjectCard(node: project, isExpanded: false, selectedNode: $selectedNode, onExpand: {
                                            selectedNode = project
                                        })
                                        .frame(width: 220)
                                    }
                                }
                            }

                            Spacer()

                            // Needs clarification
                            let uncertain = store.uncertainNodes(limit: 3)
                            if !uncertain.isEmpty {
                                VStack(alignment: .trailing, spacing: 8) {
                                    sectionLabel("Needs Input", count: uncertain.count, color: .orange)
                                    ForEach(uncertain) { node in
                                        ClarificationMiniCard(node: node, selectedNode: $selectedNode)
                                            .frame(width: 200)
                                    }
                                }
                            }
                        }

                        // Bottom: Quick add + stats
                        HStack {
                            QuickAddBar()
                                .frame(width: 300)
                            Spacer()
                            statsView
                        }
                        .padding(.top, 20)
                    }
                    .padding(24)
                }
                .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
            }
        }
        .navigationTitle("Today")
    }

    // MARK: - Connection Lines

    @ViewBuilder
    private var connectionLines: some View {
        // Visual connection indicators between related items
        Canvas { context, size in
            guard let project = mainProject else { return }
            let connected = store.connectedNodes(for: project.id)

            // Draw lines from project position to connected items
            let projectCenter = CGPoint(x: 300, y: 80)

            for (i, node) in connected.prefix(8).enumerated() {
                let angle = Double(i) * (.pi / 4) + .pi / 8
                let radius: Double = 120 + Double(i) * 20
                let endX = projectCenter.x + cos(angle) * radius
                let endY = projectCenter.y + sin(angle) * radius

                var path = Path()
                path.move(to: projectCenter)
                path.addLine(to: CGPoint(x: endX, y: endY))

                context.stroke(path, with: .color(.secondary.opacity(0.2)), lineWidth: 1)

                // Dot at connection point
                let dotRect = CGRect(x: endX - 3, y: endY - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dotRect), with: .color(node.type.color.opacity(0.5)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Expanded Children

    private func expandedChildrenView(for project: MindNode) -> some View {
        let tasks = store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
        let notes = store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .note }
        let people = store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .person }

        return VStack(alignment: .leading, spacing: 12) {
            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tasks").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(tasks.prefix(5)) { task in
                        TaskRow(task: task, selectedNode: $selectedNode)
                    }
                }
            }
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(notes.prefix(3)) { note in
                        SmallCard(node: note, selectedNode: $selectedNode)
                    }
                }
            }
            if !people.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("People").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(people) { person in
                        SmallCard(node: person, selectedNode: $selectedNode)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Computed

    private var mainProject: MindNode? {
        store.activeNodes(ofType: .project).first
    }

    private var openTasks: [MindNode] {
        store.activeNodes(ofType: .task).filter { $0.status != .completed }
    }

    private var recentNotes: [MindNode] {
        store.nodes(ofType: .note).prefix(5).map { $0 }
    }

    private var importantPeopleAndEvents: [MindNode] {
        let people = store.activeNodes(ofType: .person).filter { $0.relevance > 0.3 }
        let events = store.activeNodes(ofType: .event).filter { $0.relevance > 0.3 }
        return (people + events).sorted { $0.relevance > $1.relevance }
    }

    // MARK: - UI Helpers

    private func sectionLabel(_ title: String, count: Int, color: Color = .secondary) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.caption.bold()).foregroundStyle(color)
            Text("(\(count))").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var statsView: some View {
        HStack(spacing: 16) {
            statItem("\(store.nodes.count)", "nodes", .blue)
            statItem("\(store.links.count)", "links", .green)
            statItem("\(store.activeNodes(ofType: .task).filter { $0.status != .completed }.count)", "tasks", .orange)
        }
        .font(.caption2)
    }

    private func statItem(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).foregroundStyle(color)
            Text(label).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Card Types

/// Project card with expand/collapse.
struct ProjectCard: View {
    let node: MindNode
    let isExpanded: Bool
    @Binding var selectedNode: MindNode?
    let onExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill").foregroundStyle(.blue)
                Text(node.title).font(.headline).lineLimit(1)
                Spacer()
                if node.pinned {
                    Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                }
                Button(action: onExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if !node.body.isEmpty {
                Text(node.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }

            HStack {
                ConfidenceBadge(value: node.confidence)
                RelevanceBar(value: node.relevance).frame(width: 40, height: 3)
                Spacer()
                Text(node.status.rawValue).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.blue.opacity(isExpanded ? 0.5 : 0.15), lineWidth: isExpanded ? 2 : 1)
        )
        .onTapGesture { selectedNode = node }
    }
}

/// Small card for people, events, sources.
struct SmallCard: View {
    let node: MindNode
    @Binding var selectedNode: MindNode?

    var body: some View {
        HStack(spacing: 8) {
            Text(node.type.icon).font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(node.title).font(.caption.bold()).lineLimit(1)
                if !node.body.isEmpty {
                    Text(node.body).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onTapGesture { selectedNode = node }
    }
}

/// Note card.
struct NoteCard: View {
    let node: MindNode
    @Binding var selectedNode: MindNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.title).font(.subheadline.bold()).lineLimit(1)
            if !node.body.isEmpty {
                Text(node.body).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
            HStack {
                ConfidenceBadge(value: node.confidence)
                Spacer()
                Text(node.updatedAt, style: .relative).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onTapGesture { selectedNode = node }
    }
}

/// Mini clarification card.
struct ClarificationMiniCard: View {
    let node: MindNode
    @Binding var selectedNode: MindNode?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2).foregroundStyle(.orange)
            Text(node.title).font(.caption.bold()).lineLimit(1)
            Spacer()
            ConfidenceBadge(value: node.confidence)
        }
        .padding(8)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .onTapGesture { selectedNode = node }
    }
}
