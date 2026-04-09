import Foundation

/// Memory Router — routes questions to the right context instead of dumping everything.
///
/// Wrong way: send all 130 nodes every message.
/// Right way: detect intent → choose anchor → retrieve nearest → compress → answer.
///
/// This keeps the context small (~20 items max) and relevant to what the user asked.
@MainActor
struct BrainContext {

    // MARK: - Anchors

    enum Anchor: String {
        case today       // default — what matters now
        case project     // focused on a specific project
        case person      // focused on a specific person
        case date        // focused on a time range
        case task        // focused on tasks
        case note        // focused on notes
    }

    // MARK: - Main Router

    /// Route a question to the right context pack.
    /// This is the ONLY entry point the chat should use.
    static func route(question: String, store: NodeStore) -> String {
        let anchor = detectAnchor(question: question, store: store)

        // Build the context pack from the anchor
        let pack = buildPack(anchor: anchor, question: question, store: store)

        // Compress to a short system prompt
        return compress(pack: pack, anchor: anchor)
    }

    // MARK: - Intent Detection

    /// Detect which anchor the question points to.
    private static func detectAnchor(question: String, store: NodeStore) -> (Anchor, MindNode?) {
        let lower = question.lowercased()

        // Check for project references
        for (_, node) in store.nodes where node.type == .project {
            if lower.contains(node.title.lowercased()) {
                return (.project, node)
            }
        }
        if lower.contains("project") || lower.contains("working on") || lower.contains("focus") {
            // Find the top active project
            let top = store.activeNodes(ofType: .project).first
            return (.project, top)
        }

        // Check for person references
        for (_, node) in store.nodes where node.type == .person {
            if lower.contains(node.title.lowercased()) {
                return (.person, node)
            }
        }
        if lower.contains("who") && (lower.contains("working") || lower.contains("involved")) {
            return (.person, nil)
        }

        // Check for task references
        if lower.contains("task") || lower.contains("todo") || lower.contains("do i need")
            || lower.contains("what should i do") || lower.contains("organize") {
            return (.task, nil)
        }

        // Check for date/time references
        let dateWords = ["yesterday", "today", "last week", "last month", "monday", "tuesday",
                         "wednesday", "thursday", "friday", "saturday", "sunday"]
        for word in dateWords {
            if lower.contains(word) {
                return (.date, nil)
            }
        }
        if lower.contains("what happened") || lower.contains("what did i") {
            return (.date, nil)
        }

        // Check for note references
        if lower.contains("note") || lower.contains("idea") || lower.contains("remember") {
            return (.note, nil)
        }

        // Default: today
        return (.today, nil)
    }

    // MARK: - Context Pack Builder

    /// A context pack = a small set of relevant nodes + their connections.
    struct ContextPack {
        var focus: [MindNode] = []        // the main items
        var connected: [MindNode] = []    // directly linked items
        var nearby: [MindNode] = []       // related but less direct
        var stats: String = ""            // summary stats
        var uncertain: [MindNode] = []    // low confidence items needing attention
    }

    private static func buildPack(anchor: (Anchor, MindNode?), question: String, store: NodeStore) -> ContextPack {
        var pack = ContextPack()

        switch anchor.0 {
        case .today:
            pack = buildTodayPack(store: store)
        case .project:
            pack = buildProjectPack(focus: anchor.1, store: store)
        case .person:
            pack = buildPersonPack(focus: anchor.1, store: store)
        case .date:
            pack = buildDatePack(store: store)
        case .task:
            pack = buildTaskPack(store: store)
        case .note:
            pack = buildNotePack(store: store)
        }

        // Always include a few uncertain items (they need attention)
        pack.uncertain = store.uncertainNodes(limit: 3)

        return pack
    }

    // MARK: - Anchor: Today

    private static func buildTodayPack(store: NodeStore) -> ContextPack {
        var pack = ContextPack()

        // Focus: top project + top open tasks
        let topProject = store.activeNodes(ofType: .project)
            .filter { $0.pinned || $0.relevance > 0.7 }
            .first
        if let p = topProject {
            pack.focus.append(p)
            // Get its tasks
            pack.connected = store.children(of: p.id, linkType: .belongsTo)
                .filter { $0.type == .task && $0.status != .completed }
                .sorted { $0.relevance > $1.relevance }
                .prefix(5)
                .map { $0 }
        }

        // Top standalone tasks
        let standaloneTasks = store.activeNodes(ofType: .task)
            .filter { $0.status != .completed }
            .sorted { $0.relevance > $1.relevance }
            .prefix(3)
            .map { $0 }
        pack.nearby = standaloneTasks

        // Recent activity (last 2 days)
        let recent = store.recentNodes(days: 2, limit: 3)
        pack.nearby.append(contentsOf: recent.filter { !pack.nearby.contains($0) })

        // Stats
        let openTaskCount = store.activeNodes(ofType: .task).filter { $0.status != .completed }.count
        pack.stats = "\(store.nodes.count) nodes, \(openTaskCount) open tasks"

        return pack
    }

    // MARK: - Anchor: Project

    private static func buildProjectPack(focus: MindNode?, store: NodeStore) -> ContextPack {
        var pack = ContextPack()

        guard let project = focus ?? store.activeNodes(ofType: .project).first else {
            return pack
        }

        pack.focus = [project]

        // Direct children via belongsTo
        let children = store.children(of: project.id, linkType: .belongsTo)
        pack.connected = children.sorted { $0.relevance > $1.relevance }.prefix(10).map { $0 }

        // Other connections
        let otherConnections = store.connectedNodes(for: project.id)
            .filter { !children.contains($0) }
        pack.nearby = otherConnections.prefix(5).map { $0 }

        // Stats
        let tasks = children.filter { $0.type == .task }
        let completed = tasks.filter { $0.status == .completed }.count
        pack.stats = "\(completed)/\(tasks.count) tasks done, \(store.linksFor(nodeID: project.id).count) connections"

        return pack
    }

    // MARK: - Anchor: Person

    private static func buildPersonPack(focus: MindNode?, store: NodeStore) -> ContextPack {
        var pack = ContextPack()

        if let person = focus {
            pack.focus = [person]
            let connected = store.connectedNodes(for: person.id)
            pack.connected = connected.prefix(10).map { $0 }
        } else {
            // Show all people
            pack.focus = store.activeNodes(ofType: .person).prefix(5).map { $0 }
        }

        return pack
    }

    // MARK: - Anchor: Date

    private static func buildDatePack(store: NodeStore) -> ContextPack {
        var pack = ContextPack()

        // Recent activity (last 3 days)
        let recent = store.recentNodes(days: 3, limit: 10)
        pack.focus = recent.prefix(5).map { $0 }
        pack.nearby = recent.dropFirst(5).map { $0 }

        // Today's events
        let todayEvents = store.nodes(ofType: .event).filter { node in
            guard let due = node.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }
        pack.connected = Array(todayEvents)

        return pack
    }

    // MARK: - Anchor: Task

    private static func buildTaskPack(store: NodeStore) -> ContextPack {
        var pack = ContextPack()

        let openTasks = store.activeNodes(ofType: .task)
            .filter { $0.status != .completed }
            .sorted { $0.relevance > $1.relevance }

        pack.focus = openTasks.prefix(8).map { $0 }

        // Show which projects these belong to
        let projectIds = Set(pack.focus.compactMap { task in
            store.links.values.first(where: { $0.targetID == task.id && $0.linkType == .belongsTo })?.sourceID
        })
        pack.connected = projectIds.compactMap { store.nodes[$0] }

        return pack
    }

    // MARK: - Anchor: Note

    private static func buildNotePack(store: NodeStore) -> ContextPack {
        var pack = ContextPack()

        let recentNotes = store.recentNodes(days: 14, limit: 8).filter { $0.type == .note }
        pack.focus = recentNotes.prefix(5).map { $0 }
        pack.nearby = recentNotes.dropFirst(5).map { $0 }

        return pack
    }

    // MARK: - Compressor

    /// Compress a context pack into a small system prompt.
    private static func compress(pack: ContextPack, anchor: (Anchor, MindNode?)) -> String {
        var lines: [String] = []

        // Header
        lines.append("You are the AI assistant for MindPalantir, a personal second brain.")
        lines.append("Be concise. Be specific to their data. Ask questions when uncertain.")
        lines.append("")

        // Focus items
        if !pack.focus.isEmpty {
            lines.append("## Focus")
            for node in pack.focus {
                lines.append(formatNode(node))
            }
            lines.append("")
        }

        // Connected items
        if !pack.connected.isEmpty {
            lines.append("## Related")
            for node in pack.connected.prefix(8) {
                lines.append("- \(node.type.emoji) \(node.title) [\(node.status.rawValue)]")
            }
            lines.append("")
        }

        // Nearby items
        if !pack.nearby.isEmpty {
            lines.append("## Nearby")
            for node in pack.nearby.prefix(5) {
                lines.append("- \(node.type.emoji) \(node.title)")
            }
            lines.append("")
        }

        // Stats
        if !pack.stats.isEmpty {
            lines.append("## Stats")
            lines.append(pack.stats)
            lines.append("")
        }

        // Uncertain items
        if !pack.uncertain.isEmpty {
            lines.append("## Needs Clarification")
            for u in pack.uncertain {
                lines.append("- \(u.title) (confidence: \(Int(u.confidence * 100))%)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatters

    private static func formatNode(_ node: MindNode) -> String {
        var parts = ["\(node.type.emoji) \(node.title)"]
        parts.append("[\(node.status.rawValue), relevance: \(Int(node.relevance * 100))%]")
        if !node.body.isEmpty {
            parts.append("\n   \(node.body.prefix(120))")
        }
        return "- " + parts.joined(separator: " ")
    }

    // MARK: - Legacy (keep for non-chat uses)

    /// Build context for a specific node — used by inspector, not by chat routing.
    static func buildNodeContext(node: MindNode, store: NodeStore) -> String {
        var lines: [String] = []

        lines.append("## Focused Item: \(node.title)")
        lines.append("Type: \(node.type.rawValue) | Status: \(node.status.rawValue)")
        lines.append("Relevance: \(Int(node.relevance * 100))% | Confidence: \(Int(node.confidence * 100))%")
        if !node.body.isEmpty {
            lines.append("Details: \(node.body)")
        }
        if let origin = node.sourceOrigin {
            lines.append("Source: \(origin)")
        }

        let connected = store.connectedNodes(for: node.id)
        if !connected.isEmpty {
            lines.append("\nConnected to:")
            for c in connected.prefix(8) {
                lines.append("  \(c.type.emoji) \(c.title)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
