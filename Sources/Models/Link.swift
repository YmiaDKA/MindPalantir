import Foundation

// MARK: - Link Types (from spec)

enum LinkType: String, Codable, CaseIterable, Sendable {
    case belongsTo     // note/task belongs_to project
    case relatedTo     // generic relation
    case mentions      // note mentions person/source
    case scheduledFor  // event scheduled_for date/project
    case fromSource    // content from_source
}

// MARK: - Link

/// A directed link between two nodes. Links do not duplicate.
/// Unique by (sourceID, targetID, linkType).
struct MindLink: Identifiable, Codable, Sendable {
    let id: UUID
    let sourceID: UUID
    let targetID: UUID
    var linkType: LinkType
    var weight: Double      // 0.0 ... 1.0
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        targetID: UUID,
        linkType: LinkType = .relatedTo,
        weight: Double = 0.5
    ) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.linkType = linkType
        self.weight = weight
        self.createdAt = .now
    }

    /// Key for deduplication
    var dedupeKey: String {
        "\(sourceID.uuidString)_\(targetID.uuidString)_\(linkType.rawValue)"
    }
}
