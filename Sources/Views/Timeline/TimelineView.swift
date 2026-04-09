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
            HStack(spacing: 8) {
                ForEach(groupedByDay, id: \.0) { day, nodes in
                    Button {
                        withAnimation {
                            selectedDay = selectedDay == day ? nil : day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(shortDay(day))
                                .font(.caption.bold())
                            Text("\(nodes.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedDay == day
                                ? Color.accentColor.opacity(0.15)
                                : Color(NSColor.controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    selectedDay == day ? Color.accentColor.opacity(0.3) : .clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Horizontal day strip
            dayPills
            
            Divider()
            
            // Vertical day list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
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
                .padding()
            }
        }
        .navigationTitle("Timeline")
    }
    
    private func shortDay(_ day: String) -> String {
        // "Apr 8, 2026" → "Apr 8"
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
            HStack(spacing: 8) {
                Text(day)
                    .font(.headline)
                Text("\(nodes.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // Type summary
                typeSummary
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Nodes
            VStack(spacing: 4) {
                ForEach(nodes) { node in
                    TimelineRow(node: node, selectedNode: $selectedNode)
                }
            }
            .padding(.top, 8)
        }
    }
    
    private var typeSummary: some View {
        let counts = Dictionary(grouping: nodes, by: { $0.type })
            .mapValues { $0.count }
        
        return HStack(spacing: 6) {
            ForEach(NodeType.allCases, id: \.self) { type in
                if let count = counts[type], count > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: type.sfIcon).font(.caption2)
                        Text("\(count)").font(.caption2).foregroundStyle(.secondary)
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Type + time
            VStack(spacing: 2) {
                Image(systemName: node.type.sfIcon).font(.system(size: 14))
                Text(node.updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }
            .frame(width: 44)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if !node.body.isEmpty {
                    Text(node.body)
                        .font(.caption)
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
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            selectedNode?.id == node.id
                ? Color.accentColor.opacity(0.06)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = node }
    }
}
