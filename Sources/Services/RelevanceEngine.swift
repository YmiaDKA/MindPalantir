import Foundation

/// Periodically recalculates relevance scores based on:
/// - Recency (when last updated)
/// - Access frequency (how often viewed)
/// - Connection count (how many links)
/// - Pinned status (manual boost)
/// - Decay over time
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
        // Run once on start
        recalculateAll()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Recalculate
    
    func recalculateAll() {
        var updated = 0
        
        for (id, var node) in store.nodes {
            let oldRelevance = node.relevance
            node.relevance = calculateRelevance(for: node)
            
            if abs(oldRelevance - node.relevance) > 0.01 {
                node.updatedAt = .now
                try? store.insertNode(node)
                updated += 1
            }
        }
        
        if updated > 0 {
            print("📊 Recalculated relevance for \(updated) nodes")
        }
    }
    
    // MARK: - Scoring
    
    private func calculateRelevance(for node: MindNode) -> Double {
        // Base: type weight
        let typeWeight: Double
        switch node.type {
        case .project: typeWeight = 0.3
        case .task: typeWeight = 0.25
        case .event: typeWeight = 0.25
        case .person: typeWeight = 0.2
        case .note: typeWeight = 0.15
        case .source: typeWeight = 0.1
        }
        
        // Recency: newer = higher
        let daysSinceUpdate = Date.now.timeIntervalSince(node.updatedAt) / 86400
        let recencyScore = max(0, 1.0 - (daysSinceUpdate / 30))
        
        // Connection count: more links = more important
        let linkCount = store.linksFor(nodeID: node.id).count
        let connectionScore = min(1.0, Double(linkCount) / 5.0)
        
        // Pinned boost
        let pinnedBoost: Double = node.pinned ? 0.2 : 0
        
        // Status penalty
        let statusPenalty: Double
        switch node.status {
        case .completed: statusPenalty = 0.3
        case .archived: statusPenalty = 0.5
        case .draft: statusPenalty = 0.1
        case .active: statusPenalty = 0
        case .waiting: statusPenalty = 0.1
        }
        
        // Calculate
        let score = typeWeight + recencyScore * 0.3 + connectionScore * 0.2 + pinnedBoost - statusPenalty
        
        // Clamp
        return max(0.0, min(1.0, score))
    }
}
