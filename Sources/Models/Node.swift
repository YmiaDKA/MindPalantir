import Foundation

// MARK: - Node Types

enum NodeType: String, Codable, CaseIterable, Sendable {
    case project
    case note
    case task
    case person
    case event
    case source
}

// MARK: - Node Status

enum NodeStatus: String, Codable, Sendable {
    case active
    case completed
    case archived
    case draft
    case waiting       // blocked / needs info
}

// MARK: - Core Node

/// One thing exists once. Views are queries, not copies.
struct MindNode: Identifiable, Codable, Sendable {
    let id: UUID
    var type: NodeType
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var lastAccessedAt: Date

    // Relevance & Confidence — the two scoring systems
    var relevance: Double       // 0.0 ... 1.0 — what shows on Today/Desktop
    var confidence: Double      // 0.0 ... 1.0 — how certain is this data

    // Status
    var status: NodeStatus

    // Manual boost — user can pin important things
    var pinned: Bool

    // Source tracking — where did this come from?
    var sourceOrigin: String?   // "quick_add", "import", "hermes", "file_drop", etc.

    // Type-specific data stored as flexible key/value
    var metadata: [String: String]

    // Optional due date (tasks, events)
    var dueDate: Date?

    init(
        id: UUID = UUID(),
        type: NodeType,
        title: String,
        body: String = "",
        relevance: Double = 0.5,
        confidence: Double = 0.8,
        status: NodeStatus = .active,
        pinned: Bool = false,
        sourceOrigin: String? = nil,
        metadata: [String: String] = [:],
        dueDate: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
        self.lastAccessedAt = .now
        self.relevance = relevance
        self.confidence = confidence
        self.status = status
        self.pinned = pinned
        self.sourceOrigin = sourceOrigin
        self.metadata = metadata
        self.dueDate = dueDate
    }

    /// Touch — updates access time and bumps relevance
    mutating func touch() {
        lastAccessedAt = .now
        relevance = min(1.0, relevance + 0.03)
    }
}
