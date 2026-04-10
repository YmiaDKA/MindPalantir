import SwiftUI

/// Smart Timeline — browse your brain's history.
/// Two modes: "River" (canvas-based time river) and "List" (grouped by day).
/// Toggle with the button in the toolbar.
///
/// Keyboard:
///   ←→  move between river dots (in river mode)
///   ↑↓  move between list rows (in list mode)
///   Enter  select focused node
///   R      toggle river/list mode
struct TimelineView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @State private var selectedDay: String?
    @State private var viewMode: ViewMode = .river
    @State private var daysBack: Int = 30

    enum ViewMode: String, CaseIterable {
        case river = "River"
        case list = "List"
    }

    private var timelineNodes: [MindNode] {
        store.recentNodes(days: daysBack, limit: 200)
    }

    private var groupedByDay: [(String, [MindNode])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let grouped = Dictionary(grouping: timelineNodes) { node in
            formatter.string(from: node.updatedAt)
        }
        return grouped.sorted { a, b in
            guard let d1 = timelineNodes.first(where: { formatter.string(from: $0.updatedAt) == a.key })?.updatedAt,
                  let d2 = timelineNodes.first(where: { formatter.string(from: $0.updatedAt) == b.key })?.updatedAt
            else { return false }
            return d1 > d2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()

            if timelineNodes.isEmpty {
                emptyState
            } else if viewMode == .river {
                riverView
            } else {
                listView
            }
        }
        .background(Theme.Colors.windowBackground)
        .navigationTitle("Timeline")
        .onKeyPress("r") {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewMode = viewMode == .river ? .list : .river
            }
            return .handled
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: Theme.Spacing.md) {
            // View mode toggle
            HStack(spacing: 2) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(Theme.Fonts.caption)
                            .fontWeight(viewMode == mode ? .semibold : .regular)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                viewMode == mode
                                    ? Theme.Colors.accent.opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
                            )
                            .foregroundStyle(viewMode == mode ? Theme.Colors.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 16)

            // Time range
            Menu {
                Button("Last 7 days") { daysBack = 7 }
                Button("Last 14 days") { daysBack = 14 }
                Button("Last 30 days") { daysBack = 30 }
                Button("Last 90 days") { daysBack = 90 }
            } label: {
                Label("Last \(daysBack) days", systemImage: "calendar")
                    .font(Theme.Fonts.caption)
            }
            .menuStyle(.borderlessButton)

            Spacer()

            // Stats
            Text("\(timelineNodes.count) nodes")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)

            // Type summary
            typeSummary
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var typeSummary: some View {
        let counts = Dictionary(grouping: timelineNodes, by: { $0.type })
            .mapValues { $0.count }
        return HStack(spacing: 6) {
            ForEach(NodeType.allCases, id: \.self) { type in
                if let count = counts[type], count > 0 {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(Theme.Colors.typeColor(type))
                            .frame(width: 5, height: 5)
                        Text("\(count)")
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - River View

    private var riverView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // River canvas
            TimeRiverCanvas(
                selectedNode: $selectedNode,
                nodes: timelineNodes
            )
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)

            // Activity density strip — mini bar chart of node count per day
            densityStrip
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xs)

            Divider()

            // Legend + selected node preview
            HStack(spacing: Theme.Spacing.lg) {
                // Legend
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Legend:")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                    ForEach(NodeType.allCases, id: \.self) { type in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Theme.Colors.typeColor(type))
                                .frame(width: 6, height: 6)
                            Text(type.rawValue.capitalized)
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Keyboard hint
                Text("←→ navigate · R list · scroll to pan")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            // Day pills below river (scrollable)
            dayPills
        }
    }

    // MARK: - List View

    private var listView: some View {
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
    }

    // MARK: - Day Pills

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

    // MARK: - Density Strip

    /// Mini bar chart showing activity density per day
    private var densityStrip: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        // Group by day and count
        var dayCounts: [(String, Int)] = []
        var currentDay: String = ""
        var count = 0

        for node in timelineNodes.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            let day = formatter.string(from: node.updatedAt)
            if day != currentDay {
                if !currentDay.isEmpty {
                    dayCounts.append((currentDay, count))
                }
                currentDay = day
                count = 1
            } else {
                count += 1
            }
        }
        if !currentDay.isEmpty {
            dayCounts.append((currentDay, count))
        }

        let maxCount = dayCounts.map(\.1).max() ?? 1

        return HStack(alignment: .bottom, spacing: 1) {
            ForEach(Array(dayCounts.enumerated()), id: \.offset) { _, entry in
                let height = max(2, CGFloat(entry.1) / CGFloat(maxCount) * 20)
                VStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.Colors.accent.opacity(0.25))
                        .frame(width: 6, height: height)
                    Text(String(entry.0.prefix(3)))
                        .font(.system(size: 6))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 32)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No recent activity")
                .font(Theme.Fonts.largeTitle)
                .foregroundStyle(.secondary)
            Text("Create some nodes and they'll appear here as a flowing river of time.")
                .font(Theme.Fonts.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func shortDay(_ day: String) -> String {
        let parts = day.split(separator: ",")
        return parts.first.map(String.init) ?? day
    }
}

// MARK: - Day Section (shared between list and river detail)

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
