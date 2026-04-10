import SwiftUI

/// Full graph view — visual map of your brain.
/// Nodes as colored circles, links as lines. Force-directed layout.
/// Inspired by Obsidian Graph View, Heptabase, gbrain's graph traversal.
struct GraphView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @State private var positions: [UUID: CGPoint] = [:]
    @State private var velocities: [UUID: CGVector] = [:]
    @State private var dragNode: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var cameraOffset: CGSize = .zero
    @State private var cameraZoom: CGFloat = 1.0
    @State private var isSimulating = true
    @State private var filterType: NodeType?
    @State private var showLabels = true
    @State private var searchText: String = ""
    @State private var showSearchResults = false
    @GestureState private var panState: CGSize = .zero
    @GestureState private var magnifyState: CGFloat = 1.0
    @State private var keyboardFocusedNode: UUID?

    // Simulation parameters
    private let repulsion: CGFloat = 8000
    private let attraction: CGFloat = 0.005
    private let damping: CGFloat = 0.85
    private let idealDistance: CGFloat = 120

    // MARK: - Derived

    private var displayNodes: [MindNode] {
        let all = Array(store.nodes.values)
        if let type = filterType {
            return all.filter { $0.type == type }
        }
        return all
    }

    private var displayLinks: [(from: UUID, to: UUID, type: LinkType)] {
        let nodeIDs = Set(displayNodes.map(\.id))
        return store.links.values.compactMap { link in
            guard nodeIDs.contains(link.sourceID), nodeIDs.contains(link.targetID) else { return nil }
            return (from: link.sourceID, to: link.targetID, type: link.linkType)
        }
    }

    /// Nodes matching the search text — shown in dropdown and highlighted in graph
    private var searchMatches: [MindNode] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return displayNodes
            .filter { $0.title.lowercased().contains(query) || $0.body.lowercased().contains(query) }
            .sorted { $0.relevance > $1.relevance }
            .prefix(8)
            .map { $0 }
    }

    /// Set of node IDs that match search (for fast lookup during drawing)
    private var searchMatchIDs: Set<UUID> {
        guard !searchText.isEmpty else { return [] }
        return Set(searchMatches.map(\.id))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            graphToolbar
            Divider()
            GeometryReader { geo in
                ZStack {
                    // Canvas
                    Canvas { context, size in
                        // Apply camera transform
                        context.translateBy(
                            x: size.width / 2 + cameraOffset.width + panState.width,
                            y: size.height / 2 + cameraOffset.height + panState.height
                        )
                        context.scaleBy(x: cameraZoom * magnifyState, y: cameraZoom * magnifyState)

                        // Draw links
                        let linkOpacity: Double = searchText.isEmpty ? 0.2 : (searchMatchIDs.isEmpty ? 0.2 : 0.05)
                        for link in displayLinks {
                            guard let fromPos = positions[link.from], let toPos = positions[link.to] else { continue }
                            // Highlight links between matched nodes
                            let isMatchLink = searchMatchIDs.contains(link.from) && searchMatchIDs.contains(link.to)
                            let opacity = isMatchLink && !searchText.isEmpty ? 0.5 : linkOpacity
                            var path = Path()
                            path.move(to: fromPos)
                            path.addLine(to: toPos)
                            context.stroke(path, with: .color(.secondary.opacity(opacity)), lineWidth: isMatchLink ? 1.5 : 0.5)
                        }

                        // Draw nodes
                        for node in displayNodes {
                            guard let pos = positions[node.id] else { continue }
                            let radius = nodeRadius(node)
                            let color = Theme.Colors.typeColor(node.type)
                            let rect = CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2)

                            // Glow for search matches
                            let isSearchMatch = searchMatchIDs.contains(node.id)
                            if isSearchMatch && !searchText.isEmpty {
                                let glowRect = rect.insetBy(dx: -6, dy: -6)
                                context.fill(
                                    Path(ellipseIn: glowRect),
                                    with: .color(Theme.Colors.accent.opacity(0.25))
                                )
                            }
                            // Glow for high relevance
                            else if node.relevance > 0.7 {
                                let glowRect = rect.insetBy(dx: -4, dy: -4)
                                context.fill(
                                    Path(ellipseIn: glowRect),
                                    with: .color(color.opacity(0.15))
                                )
                            }

                            // Node circle
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(color.opacity(nodeOpacity(node)))
                            )

                            // Border
                            context.stroke(
                                Path(ellipseIn: rect),
                                with: .color(color.opacity(0.8)),
                                lineWidth: selectedNode?.id == node.id ? 2 : 0.5
                            )

                            // Selection ring
                            if selectedNode?.id == node.id {
                                let ringRect = rect.insetBy(dx: -4, dy: -4)
                                context.stroke(
                                    Path(ellipseIn: ringRect),
                                    with: .color(Theme.Colors.accent),
                                    lineWidth: 1.5
                                )
                            }

                            // Keyboard focus ring — dashed, distinct from selection
                            if keyboardFocusedNode == node.id && selectedNode?.id != node.id {
                                let focusRect = rect.insetBy(dx: -5, dy: -5)
                                var dashPath = Path()
                                dashPath.addEllipse(in: focusRect)
                                context.stroke(
                                    dashPath,
                                    with: .color(Theme.Colors.accent.opacity(0.7)),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                                )
                            } else if keyboardFocusedNode == node.id {
                                // Both selected and focused — double ring
                                let focusRect = rect.insetBy(dx: -8, dy: -8)
                                var dashPath = Path()
                                dashPath.addEllipse(in: focusRect)
                                context.stroke(
                                    dashPath,
                                    with: .color(Theme.Colors.accent.opacity(0.5)),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                )
                            }

                            // Label — always show for keyboard-focused or search-matched nodes
                            if showLabels && radius > 6 || keyboardFocusedNode == node.id {
                                let label = node.title.count > 12 ? String(node.title.prefix(11)) + "…" : node.title
                                context.draw(
                                    Text(label)
                                        .font(.system(size: max(8, 10 / cameraZoom), weight: .medium, design: .default))
                                        .foregroundStyle(.secondary),
                                    at: CGPoint(x: pos.x, y: pos.y + radius + 8)
                                )
                            }

                            // Pin indicator
                            if node.pinned {
                                let pinPos = CGPoint(x: pos.x + radius - 2, y: pos.y - radius + 2)
                                context.draw(
                                    Text("📌").font(.system(size: 8)),
                                    at: pinPos
                                )
                            }
                        }
                    }
                    .gesture(panGesture)
                    .simultaneousGesture(magnifyGesture)
                    .onAppear { initializePositions(in: geo.size) }
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                // Convert screen tap to graph coordinates
                                let centerX = geo.size.width / 2 + cameraOffset.width
                                let centerY = geo.size.height / 2 + cameraOffset.height
                                let graphX = (value.location.x - centerX) / cameraZoom
                                let graphY = (value.location.y - centerY) / cameraZoom

                                // Find closest node
                                var closest: MindNode?
                                var closestDist: CGFloat = .greatestFiniteMagnitude
                                for node in displayNodes {
                                    guard let pos = positions[node.id] else { continue }
                                    let dist = hypot(pos.x - graphX, pos.y - graphY)
                                    let radius = nodeRadius(node) + 8
                                    if dist < radius && dist < closestDist {
                                        closest = node
                                        closestDist = dist
                                    }
                                }
                                selectedNode = closest
                            }
                    )
                }
            }

            // Simulation timer
            .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
                if isSimulating && dragNode == nil {
                    simulateStep()
                }
            }

            // Search results dropdown
            if showSearchResults && !searchMatches.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchMatches) { node in
                        Button {
                            centerCamera(on: node.id)
                            selectedNode = node
                            showSearchResults = false
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Circle()
                                    .fill(Theme.Colors.typeColor(node.type))
                                    .frame(width: 6, height: 6)
                                Text(node.title)
                                    .font(Theme.Fonts.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(node.type.rawValue)
                                    .font(Theme.Fonts.tiny)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background {
                            if selectedNode?.id == node.id {
                                Theme.Colors.accent.opacity(0.08)
                            }
                        }
                    }
                }
                .frame(maxWidth: 220)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.chip)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, Theme.Spacing.lg)
                .padding(.top, 4)
            }
        }
        .navigationTitle("Graph")
        // Keyboard navigation — arrow keys to move between nodes, Enter to select, Tab to follow connection
        .onKeyPress(.upArrow) {
            navigateKeyboard(direction: CGVector(dx: 0, dy: -1))
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateKeyboard(direction: CGVector(dx: 0, dy: 1))
            return .handled
        }
        .onKeyPress(.leftArrow) {
            navigateKeyboard(direction: CGVector(dx: -1, dy: 0))
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateKeyboard(direction: CGVector(dx: 1, dy: 0))
            return .handled
        }
        .onKeyPress(.return) {
            if let focused = keyboardFocusedNode {
                selectedNode = store.nodes[focused]
            }
            return .handled
        }
        .onKeyPress(.tab) {
            followConnection()
            return .handled
        }
        .onKeyPress(.escape) {
            if keyboardFocusedNode != nil {
                keyboardFocusedNode = nil
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Keyboard Navigation

    /// Navigate keyboard focus in a direction — finds the nearest node in that quadrant.
    private func navigateKeyboard(direction: CGVector) {
        let nodes = displayNodes
        guard !nodes.isEmpty else { return }

        // Start from focused node position, or center
        let origin: CGPoint
        if let focused = keyboardFocusedNode, let pos = positions[focused] {
            origin = pos
        } else {
            keyboardFocusedNode = nodes.first?.id
            return
        }

        // Find the best candidate in the given direction
        // Score = dot product with direction (must be positive) weighted by inverse distance
        var bestScore: CGFloat = -1
        var bestNode: MindNode?

        for node in nodes {
            guard node.id != keyboardFocusedNode,
                  let pos = positions[node.id] else { continue }

            let dx = pos.x - origin.x
            let dy = pos.y - origin.y
            let dist = max(1, hypot(dx, dy))

            // Dot product — how aligned is this node with the desired direction?
            let dot = dx * direction.dx + dy * direction.dy
            guard dot > 0 else { continue }

            // Score favors nodes that are more aligned and reasonably close
            let alignment = dot / dist
            let score = alignment / sqrt(dist)
            if score > bestScore {
                bestScore = score
                bestNode = node
            }
        }

        if let best = bestNode {
            withAnimation(.easeInOut(duration: 0.15)) {
                keyboardFocusedNode = best.id
            }
        }
    }

    /// Tab: follow the strongest connection from the currently focused node
    private func followConnection() {
        let sourceID: UUID
        if let focused = keyboardFocusedNode {
            sourceID = focused
        } else if let selected = selectedNode?.id {
            sourceID = selected
            keyboardFocusedNode = selected
        } else {
            return
        }

        // Find connected nodes, sorted by link weight
        let connected = store.links.values
            .filter { $0.sourceID == sourceID || $0.targetID == sourceID }
            .sorted { $0.weight > $1.weight }

        guard let strongest = connected.first else { return }
        let targetID = strongest.sourceID == sourceID ? strongest.targetID : strongest.sourceID

        withAnimation(.easeInOut(duration: 0.15)) {
            keyboardFocusedNode = targetID
        }
    }

    // MARK: - Camera

    private func centerCamera(on nodeID: UUID) {
        guard let pos = positions[nodeID] else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            cameraOffset = CGSize(width: -pos.x * cameraZoom, height: -pos.y * cameraZoom)
        }
    }

    // MARK: - Toolbar

    private var graphToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                // Node search
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("Find node...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(Theme.Fonts.caption)
                        .frame(width: 120)
                        .onChange(of: searchText) { _, _ in
                            showSearchResults = !searchText.isEmpty
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            showSearchResults = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))

                if !searchMatches.isEmpty {
                    Text("\(searchMatches.count)")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Theme.Colors.accent.opacity(0.1), in: Capsule())
                }

                Divider().frame(height: 16)

                // Type filter
                Menu {
                    Button("All Types") { filterType = nil }
                    Divider()
                    ForEach(NodeType.allCases, id: \.self) { type in
                        Button { filterType = type } label: {
                            HStack {
                                Image(systemName: type.sfIcon)
                                Text(type.rawValue.capitalized)
                                if filterType == type { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Label(filterType?.rawValue.capitalized ?? "All", systemImage: "line.3.horizontal.decrease.circle")
                        .font(Theme.Fonts.caption)
                }
                .menuStyle(.borderlessButton)

                // Toggle labels
                Button { showLabels.toggle() } label: {
                    Image(systemName: showLabels ? "textformat" : "textformat.alt")
                }
                .help(showLabels ? "Hide labels" : "Show labels")

                // Reset layout
                Button { resetLayout() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset layout")

                // Pause/resume simulation
                Button { isSimulating.toggle() } label: {
                    Image(systemName: isSimulating ? "pause.fill" : "play.fill")
                }
                .help(isSimulating ? "Pause simulation" : "Resume simulation")

                Divider().frame(height: 16)

                // Stats
                Text("\(displayNodes.count) nodes · \(displayLinks.count) links")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)

                // Keyboard navigation hint
                if keyboardFocusedNode != nil {
                    Divider().frame(height: 16)
                    Text("↑↓←→ navigate · ↵ select · Tab follow · Esc clear")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture()
            .updating($panState) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                cameraOffset.width += value.translation.width
                cameraOffset.height += value.translation.height
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnifyState) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                cameraZoom = max(0.2, min(5.0, cameraZoom * value.magnification))
            }
    }

    // MARK: - Physics Simulation

    private func simulateStep() {
        let nodes = displayNodes
        let links = displayLinks

        // Initialize new nodes
        for node in nodes {
            if positions[node.id] == nil {
                positions[node.id] = CGPoint(
                    x: CGFloat.random(in: -200...200),
                    y: CGFloat.random(in: -200...200)
                )
                velocities[node.id] = .zero
            }
        }

        // Clean up removed nodes
        let validIDs = Set(nodes.map(\.id))
        positions = positions.filter { validIDs.contains($0.key) }
        velocities = velocities.filter { validIDs.contains($0.key) }

        guard nodes.count > 1 else { return }

        // Repulsion between all nodes
        var forces: [UUID: CGVector] = [:]
        for i in 0..<nodes.count {
            let a = nodes[i]
            guard let posA = positions[a.id] else { continue }
            var force = CGVector.zero

            for j in 0..<nodes.count {
                guard i != j else { continue }
                let b = nodes[j]
                guard let posB = positions[b.id] else { continue }

                let dx = posA.x - posB.x
                let dy = posA.y - posB.y
                let dist = max(1, sqrt(dx * dx + dy * dy))
                let repel = repulsion / (dist * dist)
                force.dx += (dx / dist) * repel
                force.dy += (dy / dist) * repel
            }
            forces[a.id] = force
        }

        // Attraction along links
        for link in links {
            guard let posFrom = positions[link.from], let posTo = positions[link.to] else { continue }
            let dx = posTo.x - posFrom.x
            let dy = posTo.y - posFrom.y
            let dist = max(1, sqrt(dx * dx + dy * dy))
            let force = attraction * (dist - idealDistance)

            let fx = (dx / dist) * force
            let fy = (dy / dist) * force

            forces[link.from, default: .zero].dx += fx
            forces[link.from, default: .zero].dy += fy
            forces[link.to, default: .zero].dx -= fx
            forces[link.to, default: .zero].dy -= fy
        }

        // Apply forces and update positions
        for node in nodes {
            guard let force = forces[node.id], var vel = velocities[node.id] else { continue }
            vel.dx = (vel.dx + force.dx) * damping
            vel.dy = (vel.dy + force.dy) * damping
            velocities[node.id] = vel

            if var pos = positions[node.id] {
                pos.x += vel.dx
                pos.y += vel.dy
                positions[node.id] = pos
            }
        }

        // Center of mass correction
        let allPositions = positions.values
        let centerX = allPositions.reduce(0) { $0 + $1.x } / CGFloat(allPositions.count)
        let centerY = allPositions.reduce(0) { $0 + $1.y } / CGFloat(allPositions.count)
        if abs(centerX) > 50 || abs(centerY) > 50 {
            for id in positions.keys {
                positions[id]!.x -= centerX * 0.1
                positions[id]!.y -= centerY * 0.1
            }
        }
    }

    // MARK: - Helpers

    private func nodeRadius(_ node: MindNode) -> CGFloat {
        let base: CGFloat = node.type == .project ? 12 : 8
        let radius = base + CGFloat(node.relevance) * 8
        // Boost matching nodes during search
        if !searchText.isEmpty && searchMatchIDs.contains(node.id) {
            return radius + 3
        }
        return radius
    }

    private func nodeOpacity(_ node: MindNode) -> Double {
        // When searching, dim non-matching nodes
        if !searchText.isEmpty && !searchMatchIDs.contains(node.id) {
            return 0.1
        }
        if node.status == .archived { return 0.3 }
        if node.status == .completed { return 0.5 }
        return 0.6 + node.relevance * 0.3
    }

    private func initializePositions(in size: CGSize) {
        guard positions.isEmpty else { return }
        let nodes = displayNodes
        let angleStep = 2 * .pi / CGFloat(max(1, nodes.count))
        let radius = min(size.width, size.height) * 0.3

        for (i, node) in nodes.enumerated() {
            let angle = angleStep * CGFloat(i)
            positions[node.id] = CGPoint(
                x: cos(angle) * radius + CGFloat.random(in: -20...20),
                y: sin(angle) * radius + CGFloat.random(in: -20...20)
            )
            velocities[node.id] = .zero
        }
    }

    private func resetLayout() {
        positions = [:]
        velocities = [:]
        cameraOffset = .zero
        cameraZoom = 1.0
    }
}
