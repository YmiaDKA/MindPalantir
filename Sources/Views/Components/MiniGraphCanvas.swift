import SwiftUI

/// Mini graph canvas — a compact visual map of a node's neighborhood.
/// Rendered as a card in ProjectDetailView. Shows the project as a central dot
/// with connected nodes arranged radially, linked by lines.
/// Inspired by gbrain's graph traversal mini-maps and Obsidian's local graph.
struct MiniGraphCanvas: View {
    @Environment(NodeStore.self) private var store
    let centerNode: MindNode
    @Binding var selectedNode: MindNode?

    /// Max nodes to show (keeps the mini graph readable)
    private let maxNodes = 20

    /// Cached layout positions — recomputed when connections change
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var hoveredNode: UUID?

    // MARK: - Derived Data

    /// Connected nodes sorted by link weight, capped at maxNodes
    private var connectedNodes: [MindNode] {
        store.connectedNodes(for: centerNode.id)
            .sorted { $0.relevance > $1.relevance }
            .prefix(maxNodes)
            .map { $0 }
    }

    /// All links between center and connected nodes (one hop only)
    private var localLinks: [(from: UUID, to: UUID, color: Color)] {
        let nodeIDs = Set(connectedNodes.map(\.id))
        return store.links.values.compactMap { link in
            if link.sourceID == centerNode.id && nodeIDs.contains(link.targetID) {
                return (from: link.sourceID, to: link.targetID, color: linkColor(link.linkType))
            }
            if link.targetID == centerNode.id && nodeIDs.contains(link.sourceID) {
                return (from: link.sourceID, to: link.targetID, color: linkColor(link.linkType))
            }
            return nil
        }
    }

    /// Links between connected nodes (secondary connections shown faintly)
    private var crossLinks: [(from: UUID, to: UUID)] {
        let nodeIDs = Set(connectedNodes.map(\.id))
        return store.links.values.compactMap { link in
            guard nodeIDs.contains(link.sourceID), nodeIDs.contains(link.targetID) else { return nil }
            return (from: link.sourceID, to: link.targetID)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.accent)
                Text("Graph")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                Text("\(connectedNodes.count) nodes")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }

            // Canvas
            if connectedNodes.isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    Canvas { context, size in
                        drawGraph(context: context, size: size)
                    }
                    .contentShape(Rectangle())
                    .onAppear { computeLayout(in: geo.size) }
                    .onChange(of: store.changeCount) { _, _ in computeLayout(in: geo.size) }
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                handleTap(at: value.location)
                            }
                    )
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.chip)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
                Text("No connections yet")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(height: 60)
    }

    // MARK: - Layout

    private func computeLayout(in size: CGSize) {
        guard !connectedNodes.isEmpty else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var positions: [UUID: CGPoint] = [:]

        // Center node
        positions[centerNode.id] = center

        // Radial layout for connected nodes
        let radius = min(size.width, size.height) * 0.35
        let angleStep = 2 * .pi / CGFloat(connectedNodes.count)

        for (i, node) in connectedNodes.enumerated() {
            let angle = angleStep * CGFloat(i) - .pi / 2
            positions[node.id] = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }

        nodePositions = positions
    }

    // MARK: - Drawing

    private func drawGraph(context: GraphicsContext, size: CGSize) {
        guard nodePositions[centerNode.id] != nil else { return }

        // Draw cross-links (between connected nodes — faint)
        for link in crossLinks {
            guard let fromPos = nodePositions[link.from],
                  let toPos = nodePositions[link.to] else { continue }
            var path = Path()
            path.move(to: fromPos)
            path.addLine(to: toPos)
            context.stroke(path, with: .color(.secondary.opacity(0.08)), lineWidth: 0.5)
        }

        // Draw primary links (center → connected)
        for link in localLinks {
            guard let fromPos = nodePositions[link.from],
                  let toPos = nodePositions[link.to] else { continue }
            var path = Path()
            path.move(to: fromPos)
            path.addLine(to: toPos)
            context.stroke(path, with: .color(link.color.opacity(0.4)), lineWidth: 1)
        }

        // Draw connected nodes
        for node in connectedNodes {
            guard let pos = nodePositions[node.id] else { continue }
            let radius: CGFloat = hoveredNode == node.id ? 8 : 6
            let color = Theme.Colors.typeColor(node.type)
            let rect = CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2)

            // Glow for high relevance
            if node.relevance > 0.7 {
                context.fill(
                    Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                    with: .color(color.opacity(0.15))
                )
            }

            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.7)))
            context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.5)), lineWidth: 0.5)

            // Label (truncated)
            if hoveredNode == node.id || connectedNodes.count <= 8 {
                let label = node.title.count > 10 ? String(node.title.prefix(9)) + "…" : node.title
                context.draw(
                    Text(label)
                        .font(.system(size: 8, weight: .medium, design: .default))
                        .foregroundStyle(.secondary),
                    at: CGPoint(x: pos.x, y: pos.y + radius + 8)
                )
            }
        }

        // Draw center node (project) — larger, accent ring
        if let centerPos = nodePositions[centerNode.id] {
            let radius: CGFloat = 10
            let color = Theme.Colors.typeColor(centerNode.type)
            let rect = CGRect(x: centerPos.x - radius, y: centerPos.y - radius, width: radius * 2, height: radius * 2)

            // Accent glow
            context.fill(
                Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)),
                with: .color(Theme.Colors.accent.opacity(0.1))
            )

            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.85)))
            context.stroke(Path(ellipseIn: rect), with: .color(Theme.Colors.accent.opacity(0.6)), lineWidth: 1.5)
        }
    }

    // MARK: - Interaction

    private func handleTap(at location: CGPoint) {
        var closest: MindNode?
        var closestDist: CGFloat = 20 // tap radius

        for node in connectedNodes {
            guard let pos = nodePositions[node.id] else { continue }
            let dist = hypot(pos.x - location.x, pos.y - location.y)
            if dist < closestDist {
                closest = node
                closestDist = dist
            }
        }

        if let node = closest {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedNode = node
            }
        }
    }

    // MARK: - Helpers

    private func linkColor(_ type: LinkType) -> Color {
        switch type {
        case .belongsTo: .blue
        case .relatedTo: .gray
        case .mentions: .purple
        case .scheduledFor: .red
        case .fromSource: .orange
        }
    }
}
