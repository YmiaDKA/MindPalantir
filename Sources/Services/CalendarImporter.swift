import Foundation
import EventKit

/// Imports calendar events as nodes. Temporal anchors are the best way to understand your brain.
@MainActor
final class CalendarImporter {
    private let eventStore = EKEventStore()
    
    /// Request calendar access and import recent events.
    func importEvents(store: NodeStore, daysBack: Int = 30, daysForward: Int = 14) async -> Int {
        // Request access
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
        } else {
            granted = await withCheckedContinuation { cont in
                eventStore.requestAccess(to: .event) { success, _ in
                    cont.resume(returning: success)
                }
            }
        }
        
        guard granted else {
            print("📅 Calendar access denied")
            return 0
        }
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: now)!
        let endDate = Calendar.current.date(byAdding: .day, value: daysForward, to: now)!
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        var imported = 0
        
        for event in events {
            // Skip if already imported (check by title + date)
            let existingNode = store.nodes.values.first { node in
                node.type == .event &&
                node.title == event.title &&
                node.metadata["event_id"] == event.eventIdentifier
            }
            
            if existingNode != nil { continue }
            
            // Build body with event details
            var bodyParts: [String] = []
            if let location = event.location, !location.isEmpty {
                bodyParts.append("📍 \(location)")
            }
            if let notes = event.notes, !notes.isEmpty {
                bodyParts.append(notes.prefix(200).description)
            }
            if event.hasAttendees {
                let attendees = event.attendees?.compactMap { $0.name }.joined(separator: ", ") ?? ""
                if !attendees.isEmpty {
                    bodyParts.append("👥 \(attendees)")
                }
            }
            
            let node = MindNode(
                type: .event,
                title: event.title ?? "Untitled Event",
                body: bodyParts.joined(separator: "\n"),
                relevance: relevanceForEvent(event),
                confidence: 0.95,
                status: event.isCompleted ? .completed : .active,
                sourceOrigin: "calendar",
                metadata: [
                    "event_id": event.eventIdentifier ?? "",
                    "calendar": event.calendar.title,
                    "all_day": event.isAllDay ? "true" : "false",
                ],
                dueDate: event.startDate
            )
            
            try? store.insertNode(node)
            imported += 1
            
            // Link to projects by date proximity
            linkEventToProjects(node: node, store: store)
        }
        
        if imported > 0 {
            store.checkpoint()
            print("📅 Imported \(imported) calendar events")
        }
        
        return imported
    }
    
    private func relevanceForEvent(_ event: EKEvent) -> Double {
        let now = Date()
        let daysDiff = abs(event.startDate.timeIntervalSince(now)) / 86400
        
        if event.startDate > now {
            // Future events
            switch daysDiff {
            case ..<1: return 0.95  // Today
            case ..<3: return 0.8   // This week
            case ..<7: return 0.6   // Next week
            default: return 0.3
            }
        } else {
            // Past events
            switch daysDiff {
            case ..<1: return 0.7   // Yesterday
            case ..<7: return 0.4   // This week
            default: return 0.2
            }
        }
    }
    
    /// Link event to projects based on date overlap.
    private func linkEventToProjects(node: MindNode, store: NodeStore) {
        guard let eventDate = node.dueDate else { return }
        
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: eventDate)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        
        // Find tasks/notes created on the same day
        let sameDay = store.nodes.values.filter { other in
            other.id != node.id &&
            other.createdAt >= dayStart && other.createdAt < dayEnd
        }
        
        for related in sameDay.prefix(3) {
            if !store.linkExists(sourceID: node.id, targetID: related.id, type: .relatedTo) {
                try? store.insertLink(MindLink(sourceID: node.id, targetID: related.id, linkType: .relatedTo, weight: 0.4))
            }
        }
    }
}

// MARK: - EKEvent extension

private extension EKEvent {
    var isCompleted: Bool {
        endDate < Date()
    }
}
