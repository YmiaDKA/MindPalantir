import SwiftUI

/// Canvas-based "time river" — a flowing timeline visualization.
/// Nodes are dots along a curved horizontal path, grouped by day.
/// Visual density shows activity clusters at a glance.
///
/// Design:
///   - Horizontal S-curve path flows across the canvas
///   - Colored dots represent nodes (type = color, relevance = size)
///   - Day bands provide subtle background grouping
///   - Day labels sit below the curve
///   - Pan with drag, zoom with trackpad pinch
///   - Click dots to select nodes, hover for tooltip
///   - Keyboard: ←→ to move between dots, Enter to select

struct TimeRiverCanvas: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    let nodes: [MindNode]  // pre-sorted by updatedAt ascending

    // Camera state
    @State private var cameraOffset: CGFloat = 0
    @State private var cameraZoom: CGFloat = 1.0
    @GestureState private var panState: CGFloat = 0
    @GestureState private var magnifyState: CGFloat = 1.0
    @State private var hasAutoScrolled = false

    // Interaction state
    @State private var hoveredNodeID: UUID?
    @State private var keyboardFocusIndex: Int?
    @State private var tooltipNode: MindNode?
    @State private var tooltipPosition: CGPoint = .zero

    // Layout constants
    private let dotSpacingBase: CGFloat = 28  // min horizontal spacing between dots
    private let riverAmplitude: CGFloat = 24  // S-curve vertical wave height
    private let riverFrequency: CGFloat = 0.008  // wave frequency
    private let dayBandHeight: CGFloat = 200
    private let labelY: CGFloat = 60  // offset below river for day labels

    // MARK: - Derived

    /// Nodes sorted by updatedAt ascending (left to right)
    private var sortedNodes: [MindNode] {
        nodes.sorted { $0.updatedAt < $1.updatedAt }
    }

    /// Day boundaries — indices where the day changes
    private var dayBoundaries: [(date: Date, startIndex: Int, label: String)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        var boundaries: [(Date, Int, String)] = []
        var lastDay: Int?

        for (i, node) in sortedNodes.enumerated() {
            let day = calendar.ordinality(of: .day, in: .era, for: node.updatedAt)
            if day != lastDay {
                let label = formatter.string(from: node.updatedAt)
                boundaries.append((node.updatedAt, i, label))
                lastDay = day
            }
        }
        return boundaries
    }

    /// Compute X position for a node at index
    private func nodeX(at index: Int, in width: CGFloat) -> CGFloat {
        let spacing = dotSpacingBase * cameraZoom
        return CGFloat(index) * spacing + cameraOffset + panState + width * 0.15
    }

    /// Compute Y position using S-curve
    private func nodeY(at index: Int, in height: CGFloat) -> CGFloat {
        let centerY = height / 2
        let x = CGFloat(index)
        // S-curve: smooth sine wave
        let wave = sin(x * riverFrequency * 100) * riverAmplitude * cameraZoom
        return centerY + wave
    }

    /// Dot radius based on relevance
    private func dotRadius(for node: MindNode) -> CGFloat {
        let base: CGFloat = 4
        let maxExtra: CGFloat = 6
        return (base + CGFloat(node.relevance) * maxExtra) * min(cameraZoom, 1.5)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Canvas drawing
                Canvas { context, size in
                    drawDayBands(context: context, size: size)
                    drawRiverPath(context: context, size: size)
                    drawNodes(context: context, size: size)
                    drawDayLabels(context: context, size: size)
                    drawTooltip(context: context, size: size)
                }
                .gesture(panGesture)
                .simultaneousGesture(magnifyGesture)
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { value in
                        handleTap(at: value.location, in: geo.size)
                    }
                )
                .onAppear {
                    if !hasAutoScrolled {
                        // Auto-center on the rightmost (most recent) nodes
                        let spacing = dotSpacingBase * cameraZoom
                        let totalWidth = CGFloat(sortedNodes.count) * spacing
                        let visibleWidth = geo.size.width
                        if totalWidth > visibleWidth {
                            cameraOffset = -(totalWidth - visibleWidth + visibleWidth * 0.1)
                        }
                        hasAutoScrolled = true
                    }
                }
                .onHover { hovering in
                    if !hovering {
                        hoveredNodeID = nil
                        tooltipNode = nil
                    }
                }

                // Hover detection overlay (invisible, tracks mouse)
                HoverTracker(
                    nodes: sortedNodes,
                    cameraOffset: cameraOffset + panState,
                    cameraZoom: cameraZoom * magnifyState,
                    dotSpacingBase: dotSpacingBase,
                    canvasSize: geo.size,
                    hoveredNodeID: $hoveredNodeID,
                    tooltipNode: $tooltipNode,
                    tooltipPosition: $tooltipPosition
                )
            }
        }
        .frame(minHeight: 180, idealHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.cardBackground.opacity(0.5))
        )
        // Keyboard navigation
        .onKeyPress(.rightArrow) { moveKeyboardFocus(direction: 1); return .handled }
        .onKeyPress(.leftArrow) { moveKeyboardFocus(direction: -1); return .handled }
        .onKeyPress(.return) { selectKeyboardFocused(); return .handled }
        .onKeyPress(.escape) { keyboardFocusIndex = nil; return .handled }
        .onKeyPress("j") { moveKeyboardFocus(direction: 1); return .handled }
        .onKeyPress("k") { moveKeyboardFocus(direction: -1); return .handled }
    }

    // MARK: - Drawing

    /// Draw alternating day background bands
    private func drawDayBands(context: GraphicsContext, size: CGSize) {
        guard !dayBoundaries.isEmpty else { return }

        let colors: [Color] = [.clear, Theme.Colors.accent.opacity(0.02)]

        for (i, boundary) in dayBoundaries.enumerated() {
            let startX = nodeX(at: boundary.startIndex, in: size.width)
            let endX: CGFloat
            if i + 1 < dayBoundaries.count {
                endX = nodeX(at: dayBoundaries[i + 1].startIndex, in: size.width)
            } else {
                endX = size.width
            }

            let bandRect = CGRect(x: startX, y: 0, width: max(0, endX - startX), height: size.height)
            let color = colors[i % colors.count]
            context.fill(Path(bandRect), with: .color(color))
        }
    }

    /// Draw the flowing river path + density glow
    private func drawRiverPath(context: GraphicsContext, size: CGSize) {
        guard sortedNodes.count > 1 else { return }

        var path = Path()
        let firstX = nodeX(at: 0, in: size.width)
        let firstY = nodeY(at: 0, in: size.height)
        path.move(to: CGPoint(x: firstX, y: firstY))

        for i in 1..<sortedNodes.count {
            let x = nodeX(at: i, in: size.width)
            let y = nodeY(at: i, in: size.height)
            let prevX = nodeX(at: i - 1, in: size.width)
            let prevY = nodeY(at: i - 1, in: size.height)

            // Smooth cubic bezier between points
            let cpX = (prevX + x) / 2
            path.addCurve(
                to: CGPoint(x: x, y: y),
                control1: CGPoint(x: cpX, y: prevY),
                control2: CGPoint(x: cpX, y: y)
            )
        }

        // River stroke — subtle gradient line
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    Theme.Colors.accent.opacity(0.06),
                    Theme.Colors.accent.opacity(0.18),
                    Theme.Colors.accent.opacity(0.06)
                ]),
                startPoint: CGPoint(x: 0, y: size.height / 2),
                endPoint: CGPoint(x: size.width, y: size.height / 2)
            ),
            style: StrokeStyle(lineWidth: 2 * cameraZoom, lineCap: .round)
        )

        // Density glow — nodes that are close together in time create a brighter band
        drawDensityGlow(context: context, size: size)

        // Today marker
        drawTodayMarker(context: context, size: size)
    }

    /// Draw a glow effect where activity is dense (many nodes close together)
    private func drawDensityGlow(context: GraphicsContext, size: CGSize) {
        guard sortedNodes.count > 2 else { return }

        // Find clusters: groups of 3+ nodes within a short time span
        let clusterThreshold: TimeInterval = 3600 * 4  // 4 hours
        var i = 0
        while i < sortedNodes.count - 1 {
            var clusterEnd = i
            for j in (i + 1)..<sortedNodes.count {
                let timeDelta = sortedNodes[j].updatedAt.timeIntervalSince(sortedNodes[i].updatedAt)
                if timeDelta <= clusterThreshold {
                    clusterEnd = j
                } else {
                    break
                }
            }

            if clusterEnd - i >= 2 {
                // Draw glow between first and last node of cluster
                let startX = nodeX(at: i, in: size.width)
                let endX = nodeX(at: clusterEnd, in: size.width)
                let midIdx = (i + clusterEnd) / 2
                let midY = nodeY(at: midIdx, in: size.height)
                let glowHeight: CGFloat = 40 * cameraZoom

                let glowRect = CGRect(
                    x: startX - 4,
                    y: midY - glowHeight / 2,
                    width: endX - startX + 8,
                    height: glowHeight
                )

                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(Theme.Colors.accent.opacity(0.04))
                )
                i = clusterEnd + 1
            } else {
                i += 1
            }
        }
    }

    /// Draw a vertical "today" marker line
    private func drawTodayMarker(context: GraphicsContext, size: CGSize) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for (i, node) in sortedNodes.enumerated() {
            let nodeDay = calendar.startOfDay(for: node.updatedAt)
            if nodeDay >= today {
                let x = nodeX(at: i, in: size.width)
                guard x > 0 && x < size.width else { return }

                var markerPath = Path()
                markerPath.move(to: CGPoint(x: x, y: 8))
                markerPath.addLine(to: CGPoint(x: x, y: size.height - 30))

                context.stroke(
                    markerPath,
                    with: .color(Theme.Colors.accent.opacity(0.3)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )

                context.draw(
                    Text("Today")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.accent.opacity(0.7)),
                    at: CGPoint(x: x, y: 6)
                )
                return
            }
        }
    }

    /// Draw node dots on the river
    private func drawNodes(context: GraphicsContext, size: CGSize) {
        for (i, node) in sortedNodes.enumerated() {
            let x = nodeX(at: i, in: size.width)
            let y = nodeY(at: i, in: size.height)

            // Skip off-screen nodes
            guard x > -20 && x < size.width + 20 else { continue }

            let radius = dotRadius(for: node)
            let color = Theme.Colors.typeColor(node.type)
            let isSelected = selectedNode?.id == node.id
            let isHovered = hoveredNodeID == node.id
            let isKeyboardFocused = keyboardFocusIndex == i

            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)

            // Glow for selected/hovered
            if isSelected || isHovered {
                let glowRect = rect.insetBy(dx: -5, dy: -5)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(color.opacity(0.2))
                )
            }

            // Keyboard focus ring
            if isKeyboardFocused && !isSelected {
                let focusRect = rect.insetBy(dx: -4, dy: -4)
                var dashPath = Path()
                dashPath.addEllipse(in: focusRect)
                context.stroke(
                    dashPath,
                    with: .color(Theme.Colors.accent.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )
            }

            // Dot fill
            context.fill(
                Path(ellipseIn: rect),
                with: .color(color.opacity(nodeOpacity(node)))
            )

            // Selection ring
            if isSelected {
                let ringRect = rect.insetBy(dx: -3, dy: -3)
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(Theme.Colors.accent),
                    lineWidth: 2
                )
            }

            // Pin indicator
            if node.pinned {
                let pinPos = CGPoint(x: x + radius + 2, y: y - radius - 2)
                context.draw(
                    Text("•").font(.system(size: 8, weight: .bold)).foregroundStyle(.orange),
                    at: pinPos
                )
            }

            // Label for selected/hovered large dots
            if radius > 8 && (isHovered || isSelected) {
                let label = node.title.count > 8 ? String(node.title.prefix(7)) + "…" : node.title
                context.draw(
                    Text(label)
                        .font(.system(size: max(7, 9 / cameraZoom), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9)),
                    at: CGPoint(x: x, y: y)
                )
            }
        }
    }

    /// Draw day labels below the curve
    private func drawDayLabels(context: GraphicsContext, size: CGSize) {
        for boundary in dayBoundaries {
            let x = nodeX(at: boundary.startIndex, in: size.width)
            guard x > -40 && x < size.width + 40 else { continue }

            let y = size.height - 24
            context.draw(
                Text(boundary.label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary),
                at: CGPoint(x: x + 4, y: y)
            )

            // Day tick mark
            let riverY = nodeY(at: boundary.startIndex, in: size.height)
            var tickPath = Path()
            tickPath.move(to: CGPoint(x: x, y: riverY + 12))
            tickPath.addLine(to: CGPoint(x: x, y: y - 10))
            context.stroke(
                tickPath,
                with: .color(.secondary.opacity(0.2)),
                style: StrokeStyle(lineWidth: 0.5, dash: [2, 2])
            )
        }
    }

    /// Draw tooltip for hovered node
    private func drawTooltip(context: GraphicsContext, size: CGSize) {
        guard let node = tooltipNode else { return }

        let text = Text(node.title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)

        let subtitle = Text(node.type.rawValue.capitalized + " · " + node.updatedAt.formatted(.relative(presentation: .named)))
            .font(.system(size: 9))
            .foregroundStyle(.secondary)

        let tooltipWidth: CGFloat = min(200, CGFloat(node.title.count) * 7 + 20)
        let tooltipRect = CGRect(
            x: tooltipPosition.x - tooltipWidth / 2,
            y: tooltipPosition.y - 44,
            width: tooltipWidth,
            height: 36
        )

        // Background pill
        context.fill(
            Path(roundedRect: tooltipRect, cornerRadius: 6),
            with: .color(Color(NSColor.controlBackgroundColor))
        )
        context.stroke(
            Path(roundedRect: tooltipRect, cornerRadius: 6),
            with: .color(.secondary.opacity(0.3)),
            lineWidth: 0.5
        )

        // Text
        context.draw(text, at: CGPoint(x: tooltipRect.midX, y: tooltipRect.midY - 6))
        context.draw(subtitle, at: CGPoint(x: tooltipRect.midX, y: tooltipRect.midY + 8))
    }

    // MARK: - Node Opacity

    private func nodeOpacity(_ node: MindNode) -> Double {
        if selectedNode?.id == node.id { return 1.0 }
        if hoveredNodeID == node.id { return 0.9 }
        if node.relevance > 0.7 { return 0.85 }
        if node.relevance > 0.4 { return 0.65 }
        return 0.45
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture()
            .updating($panState) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                cameraOffset += value.translation.width
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnifyState) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let newZoom = cameraZoom * value.magnification
                cameraZoom = max(0.3, min(3.0, newZoom))
            }
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint, in size: CGSize) {
        var closest: MindNode?
        var closestDist: CGFloat = .greatestFiniteMagnitude

        for (i, node) in sortedNodes.enumerated() {
            let x = nodeX(at: i, in: size.width)
            let y = nodeY(at: i, in: size.height)
            let dist = hypot(location.x - x, location.y - y)
            let radius = dotRadius(for: node) + 6  // tap target
            if dist < radius && dist < closestDist {
                closest = node
                closestDist = dist
            }
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            selectedNode = closest
            if let node = closest {
                keyboardFocusIndex = sortedNodes.firstIndex(where: { $0.id == node.id })
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func moveKeyboardFocus(direction: Int) {
        guard !sortedNodes.isEmpty else { return }
        if let current = keyboardFocusIndex {
            let newIdx = max(0, min(sortedNodes.count - 1, current + direction))
            withAnimation(.easeInOut(duration: 0.1)) {
                keyboardFocusIndex = newIdx
            }
        } else {
            keyboardFocusIndex = direction > 0 ? 0 : sortedNodes.count - 1
        }
    }

    private func selectKeyboardFocused() {
        guard let idx = keyboardFocusIndex, idx < sortedNodes.count else { return }
        selectedNode = sortedNodes[idx]
    }
}

// MARK: - Hover Tracker

/// Invisible overlay that tracks mouse position to detect hover over dots.
/// Canvas doesn't have built-in hover tracking per element, so we use a UIView.
private struct HoverTracker: NSViewRepresentable {
    let nodes: [MindNode]
    let cameraOffset: CGFloat
    let cameraZoom: CGFloat
    let dotSpacingBase: CGFloat
    let canvasSize: CGSize
    @Binding var hoveredNodeID: UUID?
    @Binding var tooltipNode: MindNode?
    @Binding var tooltipPosition: CGPoint

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onMouseMove = { point in
            updateHover(at: point)
        }
        view.onMouseExit = {
            hoveredNodeID = nil
            tooltipNode = nil
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func updateHover(at point: CGPoint) {
        var closest: MindNode?
        var closestDist: CGFloat = .greatestFiniteMagnitude
        var closestPos: CGPoint = .zero

        for (i, node) in nodes.enumerated() {
            let spacing = dotSpacingBase * cameraZoom
            let x = CGFloat(i) * spacing + cameraOffset + canvasSize.width * 0.15
            let centerY = canvasSize.height / 2
            let wave = sin(CGFloat(i) * 0.8) * 30 * cameraZoom
            let y = centerY + wave

            let dist = hypot(point.x - x, point.y - y)
            let base: CGFloat = 4
            let maxExtra: CGFloat = 6
            let radius = (base + CGFloat(node.relevance) * maxExtra) * min(cameraZoom, 1.5) + 8

            if dist < radius && dist < closestDist {
                closest = node
                closestDist = dist
                closestPos = CGPoint(x: x, y: y)
            }
        }

        hoveredNodeID = closest?.id
        tooltipNode = closest
        tooltipPosition = closestPos
    }
}

/// Tracking NSView that reports mouse movement
private class TrackingView: NSView {
    var onMouseMove: ((CGPoint) -> Void)?
    var onMouseExit: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMouseMove?(point)
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExit?()
    }
}

