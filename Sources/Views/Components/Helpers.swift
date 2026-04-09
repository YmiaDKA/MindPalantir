import SwiftUI

// MARK: - Relevance Bar

struct RelevanceBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color).frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
    }

    private var color: Color {
        switch value {
        case 0.7...: .green
        case 0.4..<0.7: .orange
        default: .secondary
        }
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let value: Double

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch value {
        case 0.8...: "high"
        case 0.5..<0.8: "med"
        default: "low"
        }
    }

    private var color: Color {
        switch value {
        case 0.8...: .green
        case 0.5..<0.8: .orange
        default: .red
        }
    }
}

// MARK: - NodeType Icons

extension NodeType {
    /// Emoji text icon — used only for LLM context strings (BrainContext, BrainTools)
    var emoji: String {
        switch self {
        case .project: "📁"
        case .note: "📝"
        case .task: "✅"
        case .person: "👤"
        case .event: "📅"
        case .source: "🔗"
        }
    }

    /// SF Symbol name — use in all SwiftUI views
    var sfIcon: String {
        switch self {
        case .project: "folder.fill"
        case .note: "note.text"
        case .task: "checkmark.circle"
        case .person: "person.fill"
        case .event: "calendar"
        case .source: "link"
        }
    }

    var color: Color {
        switch self {
        case .project: .blue
        case .note: .cyan
        case .task: .green
        case .person: .purple
        case .event: .red
        case .source: .orange
        }
    }
}
