import Foundation

/// Multi-signal relevance scoring — what matters NOW, not a disconnected formula.
///
/// Signals (weighted):
/// - Recency decay (0.25): how recently was this touched
/// - Open state (0.20): open tasks boost projects, completed tasks sink
/// - Connection density (0.15): how woven into the graph
/// - Project activity (0.15): is the parent project alive
/// - Event proximity (0.10): is something due soon
/// - Access frequency (0.10): has the user been looking at this
/// - Pin boost (0.05): manual override
///
/// Each signal is 0...1, weighted sum gives final relevance.
/// Completed/archived items get steep penalties.
@MainActor
final class RelevanceEngine {
    private let store: NodeStore
    private var timer: Timer?

    init(store: NodeStore) {
        self.store = store
    }

    func start(interval: TimeInterval = 300) { // every 5 min
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recalculateAll()
            }
        }
        recalculateAll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Recalculate

    func recalculateAll() {
        var updated = 0

        for (_, var node) in store.nodes {
            let oldRelevance = node.relevance
            node.relevance = calculateRelevance(for: node)

            if abs(oldRelevance - node.relevance) > 0.01 {
                try? store.insertNode(node)
                updated += 1
            }
        }

        if updated > 0 {
            print("📊 Recalculated relevance for \(updated) nodes")
        }
    }

    // MARK: - Multi-Signal Scoring

    private func calculateRelevance(for node: MindNode) -> Double {
        // Status gate — completed/archived are always low
        switch node.status {
        case .completed:
            return max(0.05, recencyScore(node) * 0.15)
        case .archived:
            return 0.02
        case .active, .draft, .waiting:
            break
        }

        let signals: [(weight: Double, score: Double)] = [
            (0.25, recencyScore(node)),
            (0.20, openStateScore(node)),
            (0.15, connectionScore(node)),
            (0.15, projectActivityScore(node)),
            (0.10, eventProximityScore(node)),
            (0.10, accessFrequencyScore(node)),
            (0.05, node.pinned ? 1.0 : 0.0),
        ]

        let score = signals.reduce(0.0) { $0 + $1.weight * $1.score }
        return max(0.0, min(1.0, score))
    }

    // MARK: - Signal: Recency

    /// Recently touched = more relevant. Half-life of 7 days.
    private func recencyScore(_ node: MindNode) -> Double {
        let hoursSince = Date.now.timeIntervalSince(node.updatedAt) / 3600
        return exp(-hoursSince / (7 * 24 * 0.693)) // half-life = 7 days
    }

    // MARK: - Signal: Open State

    /// Open tasks boost their project. Incomplete task count = urgency.
    private func openStateScore(_ node: MindNode) -> Double {
        switch node.type {
        case .task:
            return node.status == .active ? 1.0 : 0.0
        case .project:
            let tasks = store.children(of: node.id, linkType: .belongsTo).filter { $0.type == .task }
            guard !tasks.isEmpty else { return 0.3 } // project with no tasks = neutral
            let openTasks = tasks.filter { $0.status == .active }.count
            let ratio = Double(openTasks) / Double(tasks.count)
            // More open tasks = higher urgency, but also consider completion progress
            let completionBonus = 1.0 - ratio // some completion = active project
            return 0.4 + 0.3 * ratio + 0.3 * completionBonus
        case .event:
            if let due = node.dueDate, due > Date() { return 1.0 }
            return 0.1
        default:
            return node.status == .active ? 0.5 : 0.1
        }
    }

    // MARK: - Signal: Connection Density

    /// More links = more woven into the knowledge graph.
    private func connectionScore(_ node: MindNode) -> Double {
        let linkCount = store.linksFor(nodeID: node.id).count
        return min(1.0, Double(linkCount) / 8.0)
    }

    // MARK: - Signal: Project Activity

    /// If this node belongs to an active project, boost it.
    /// If the parent project was recently touched, boost more.
    private func projectActivityScore(_ node: MindNode) -> Double {
        // Find parent projects via belongsTo links
        let parentProjects = store.links.values
            .filter { $0.targetID == node.id && $0.linkType == .belongsTo }
            .compactMap { store.nodes[$0.sourceID] }
            .filter { $0.type == .project }

        guard let project = parentProjects.first else {
            // Not part of any project — neutral
            return 0.3
        }

        // Project recency
        let hoursSinceProjectUpdate = Date.now.timeIntervalSince(project.updatedAt) / 3600
        let projectRecency = exp(-hoursSinceProjectUpdate / (14 * 24 * 0.693))

        // Project relevance feeds back — active projects lift their children
        return 0.3 + 0.7 * projectRecency
    }

    // MARK: - Signal: Event Proximity

    /// Events due soon are highly relevant. Tasks with due dates too.
    private func eventProximityScore(_ node: MindNode) -> Double {
        guard let due = node.dueDate else { return 0.2 }

        let hoursUntil = due.timeIntervalSince(Date.now) / 3600

        if hoursUntil < 0 {
            // Overdue — still relevant (needs attention)
            let hoursOverdue = -hoursUntil
            return max(0.3, exp(-hoursOverdue / (7 * 24 * 0.693)))
        }

        // Due soon = high relevance. Exponential decay from due date.
        // Within 24h: 1.0. Within 3 days: 0.7. Within 7 days: 0.4.
        return exp(-hoursUntil / (5 * 24 * 0.693))
    }

    // MARK: - Signal: Access Frequency

    /// User has been looking at this = it matters to them.
    /// Combines recency of access with total access count (preference memory).
    private func accessFrequencyScore(_ node: MindNode) -> Double {
        let hoursSinceAccess = Date.now.timeIntervalSince(node.lastAccessedAt) / 3600
        let recencyScore = exp(-hoursSinceAccess / (3 * 24 * 0.693)) // half-life = 3 days
        // Access count bonus: frequently viewed items get a boost (log scale, caps at ~0.3)
        let countBonus = min(0.3, log2(Double(node.accessCount) + 1) * 0.1)
        return min(1.0, recencyScore + countBonus)
    }
}
