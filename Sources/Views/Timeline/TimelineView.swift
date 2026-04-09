import SwiftUI

/// Rich timeline with day groups, horizontal strips, and inline previews.
struct TimelineView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @State private var selectedDay: String?

    private var groupedByDay: [(String, [MindNode])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let allNodes = store.recentNodes(days: 30, limit: 100)
        let grouped = Dictionary(grouping: allNodes) { node in
            formatter.string(from: node.updatedAt)
        }
        return grouped.sorted { a, b in
            guard let d1 = allNodes.first(where: { formatter.string(from: $0.updatedAt) == a.key })?.updatedAt,
                  let d2 = allNodes.first(where: { formatter.string(from: $0.updatedAt) == b.key })?.updatedAt
            else { return false }
            return d1 > d2
        }
    }

    // Top strip: day pills
    private var dayPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(groupedByDay, id: \.0) { day, nodes in
                    Button {
                        withAnimation {
                            selectedDay = selectedDay == day ? nil : day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(shortDay(day))
                                .font(Theme.Fonts.caption)
                                .fontWeight(.bold)
                            Text("\(nodes.count)")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            selectedDay == day
                                ? Theme.Colors.accent.opacity(0.15)
                                : Color(NSColor.controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                                .strokeBorder(
                                    selectedDay == day ? Theme.Colors.accent.opacity(0.3) : .clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dayPills

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedByDay, id: \.0) { day, nodes in
                        if selectedDay == nil || selectedDay == day {
                            DaySection(
                                day: day,
                                nodes: nodes,
                                selectedNode: $selectedNode,
                                isHighlighted: selectedDay == day
                            )
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .navigationTitle("Timeline")
    }

    private func shortDay(_ day: String) -> String {
        let parts = day.split(separator: ",")
        return parts.first.map(String.init) ?? day
    }
}

// MARK: - Day Section

struct DaySection: View {
    let day: String
    let nodes: [MindNode]
    @Binding var selectedNode: MindNode?
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sticky header
            HStack(spacing: Theme.Spacing.sm) {
                Text(day)
                    .font(Theme.Fonts.headline)
                Text("\(nodes.count) items")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                typeSummary
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.md)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))

            // Nodes
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(nodes) { node in
                    TimelineRow(node: node, selectedNode: $selectedNode)
                }
            }
            .padding(.top, Theme.Spacing.sm)
        }
    }

    private var typeSummary: some View {
        let counts = Dictionary(grouping: nodes, by: { $0.type })
            .mapValues { $0.count }

        return HStack(spacing: 6) {
            ForEach(NodeType.allCases, id: \.self) { type in
                if let count = counts[type], count > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: type.sfIcon)
                            .font(Theme.Fonts.caption)
                        Text("\(count)")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Timeline Row

struct TimelineRow: View {
    let node: MindNode
    @Binding var selectedNode: MindNode?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Type + time
            VStack(spacing: 2) {
                Image(systemName: node.type.sfIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.typeColor(node.type))
                Text(node.updatedAt, style: .time)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }
            .frame(width: 44)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(Theme.Fonts.headline)
                    .lineLimit(1)
                if !node.body.isEmpty {
                    Text(node.body)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            // Metadata
            VStack(alignment: .trailing, spacing: 2) {
                ConfidenceBadge(value: node.confidence)
                if node.pinned {
                    Image(systemName: "pin.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            selectedNode?.id == node.id
                ? Theme.Colors.accent.opacity(0.06)
                : isHovered
                    ? Color(NSColor.controlBackgroundColor).opacity(0.5)
                    : Color.clear,
            in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = hovering }
        }
        .onTapGesture { selectedNode = node }
    }
}
