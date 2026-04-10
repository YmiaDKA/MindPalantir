import Foundation

/// A milestone is a checkpoint within a project — a marker of progress.
/// Stored as JSON in project node metadata (key: "milestones").
/// This avoids schema changes and keeps milestones self-contained within the project.
struct Milestone: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var dueDate: Date?
    var completedDate: Date?
    var sortOrder: Int
    var note: String

    /// Computed: is this milestone done?
    var isCompleted: Bool {
        completedDate != nil
    }

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        completedDate: Date? = nil,
        sortOrder: Int = 0,
        note: String = ""
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.completedDate = completedDate
        self.sortOrder = sortOrder
        self.note = note
    }

    /// Mark as completed (or toggle off)
    mutating func toggleComplete() {
        if isCompleted {
            completedDate = nil
        } else {
            completedDate = .now
        }
    }

    // MARK: - Serialization

    /// Encode milestones to JSON string for storage in node metadata
    static func encode(_ milestones: [Milestone]) -> String {
        guard let data = try? JSONEncoder().encode(milestones),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }

    /// Decode milestones from JSON string
    static func decode(_ json: String) -> [Milestone] {
        guard let data = json.data(using: .utf8),
              let milestones = try? JSONDecoder().decode([Milestone].self, from: data)
        else { return [] }
        return milestones.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Metadata Key

extension Milestone {
    /// The metadata key used to store milestones in a project node
    static let metadataKey = "milestones"
}
