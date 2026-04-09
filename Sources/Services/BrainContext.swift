import Foundation

/// Builds a structured context from the entire brain for the LLM.
/// This is the "rabbithole" — the AI sees EVERYTHING about you.
@MainActor
struct BrainContext {
    
    /// Build full brain dump as a system prompt context string.
    /// Keeps it under ~8K tokens by summarizing intelligently.
    static func build(from store: NodeStore) -> String {
        var sections: [String] = []
        
        sections.append("""
        You are the AI assistant for MindPalantir, a personal second brain.
        You have full access to the user's brain data below.
        Your job: help organize, find connections, ask clarifying questions, and surface relevant info.
        Be concise. Be specific to THEIR data. Ask questions when uncertain.
        """)
        
        // Projects
        let projects = store.activeNodes(ofType: .project)
        if !projects.isEmpty {
            var projLines = ["## Active Projects"]
            for p in projects.sorted(by: { $0.relevance > $1.relevance }).prefix(10) {
                let status = p.status == .completed ? "✅" : (p.pinned ? "📌" : "○")
                let tasks = store.children(of: p.id, linkType: .belongsTo).filter { $0.type == .task }
                let openTasks = tasks.filter { $0.status != .completed }
                let taskSummary = openTasks.isEmpty ? "" : " (\(openTasks.count) open tasks)"
                projLines.append("\(status) \(p.title) — relevance: \(Int(p.relevance * 100))%\(taskSummary)")
                if !p.body.isEmpty {
                    projLines.append("   \(p.body.prefix(100))")
                }
            }
            sections.append(projLines.joined(separator: "\n"))
        }
        
        // Tasks
        let openTasks = store.activeNodes(ofType: .task).filter { $0.status != .completed }
        if !openTasks.isEmpty {
            var taskLines = ["## Open Tasks"]
            for t in openTasks.sorted(by: { $0.relevance > $1.relevance }).prefix(15) {
                let due = t.dueDate.map { " (due: \($0.formatted(date: .abbreviated, time: .omitted)))" } ?? ""
                taskLines.append("- \(t.title)\(due) [relevance: \(Int(t.relevance * 100))%]")
            }
            sections.append(taskLines.joined(separator: "\n"))
        }
        
        // People
        let people = store.activeNodes(ofType: .person)
        if !people.isEmpty {
            var peopleLines = ["## People"]
            for p in people.prefix(10) {
                peopleLines.append("- \(p.title): \(p.body.prefix(80))")
            }
            sections.append(peopleLines.joined(separator: "\n"))
        }
        
        // Recent notes (last 7 days)
        let recentNotes = store.recentNodes(days: 7, limit: 10).filter { $0.type == .note }
        if !recentNotes.isEmpty {
            var noteLines = ["## Recent Notes (last 7 days)"]
            for n in recentNotes {
                noteLines.append("- \(n.title): \(n.body.prefix(80))")
            }
            sections.append(noteLines.joined(separator: "\n"))
        }
        
        // Events
        let events = store.nodes(ofType: .event).prefix(5)
        if !events.isEmpty {
            var eventLines = ["## Events"]
            for e in events {
                let due = e.dueDate.map { " (\($0.formatted(date: .abbreviated, time: .shortened)))" } ?? ""
                eventLines.append("- \(e.title)\(due)")
            }
            sections.append(eventLines.joined(separator: "\n"))
        }
        
        // Connection stats
        let topConnected = store.nodes.values
            .map { node in (node, store.linksFor(nodeID: node.id).count) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
        
        if !topConnected.isEmpty {
            var linkLines = ["## Most Connected Items"]
            for (node, count) in topConnected {
                linkLines.append("- \(node.type.icon) \(node.title): \(count) connections")
            }
            sections.append(linkLines.joined(separator: "\n"))
        }
        
        // Low confidence items (need clarification)
        let uncertain = store.uncertainNodes(limit: 5)
        if !uncertain.isEmpty {
            var uncLines = ["## Items Needing Clarification"]
            for u in uncertain {
                uncLines.append("- \(u.title) (confidence: \(Int(u.confidence * 100))%)")
            }
            sections.append(uncLines.joined(separator: "\n"))
        }
        
        return sections.joined(separator: "\n\n")
    }
    
    /// Build context for a specific node — focused view.
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
                lines.append("  \(c.type.icon) \(c.title)")
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Build context filtered by date range — "what happened on April 5?"
    static func buildDateContext(date: Date, store: NodeStore) -> String {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        
        let dayNodes = store.nodes.values.filter { node in
            node.createdAt >= dayStart && node.createdAt < dayEnd ||
            node.updatedAt >= dayStart && node.updatedAt < dayEnd ||
            (node.dueDate != nil && node.dueDate! >= dayStart && node.dueDate! < dayEnd)
        }
        
        guard !dayNodes.isEmpty else {
            return "No data found for \(date.formatted(date: .long, time: .omitted))."
        }
        
        var lines = ["## Data for \(date.formatted(date: .long, time: .omitted))"]
        
        let created = dayNodes.filter { $0.createdAt >= dayStart && $0.createdAt < dayEnd }
        if !created.isEmpty {
            lines.append("Created:")
            for n in created { lines.append("  \(n.type.icon) \(n.title)") }
        }
        
        let createdIds = Set(created.map { $0.id })
        let updated = dayNodes.filter { $0.updatedAt >= dayStart && $0.updatedAt < dayEnd && !createdIds.contains($0.id) }
        if !updated.isEmpty {
            lines.append("Updated:")
            for n in updated { lines.append("  \(n.type.icon) \(n.title)") }
        }
        
        return lines.joined(separator: "\n")
    }
}
