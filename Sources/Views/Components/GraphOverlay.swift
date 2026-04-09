import SwiftUI

/// Simple graph view showing node connections as a visual map.
/// Not a full whiteboard — just a visual overview of relationships.
struct GraphOverlay: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    
    // Layout: place nodes in a circular pattern around center
    private var layoutNodes: [(MindNode, CGPoint)] {
        let centerNodes = store.activeNodes(ofType: .project)
        let allNodes = Array(store.nodes.values)
        guard !allNodes.isEmpty else { return [] }
        
        var result: [(MindNode, CGPoint)] = []
        let center = CGPoint(x: 250, y: 200)
        
        // Place projects in center
        for (i, project) in centerNodes.enumerated() {
            let angle = Double(i) * (.pi * 2 / Double(max(centerNodes.count, 1)))
            let r: Double = 40
            let point = CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            )
            result.append((project, point))
        }
        
        // Place other nodes in outer ring
        let outerNodes = allNodes.filter { $0.type != .project }
        for (i, node) in outerNodes.prefix(20).enumerated() {
            let angle = Double(i) * (.pi * 2 / Double(min(outerNodes.count, 20)))
            let r: Double = 120 + Double(node.type == .person ? 20 : 0)
            let point = CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            )
            result.append((node, point))
        }
        
        return result
    }
    
    private var nodePositions: [UUID: CGPoint] {
        Dictionary(uniqueKeysWithValues: layoutNodes.map { ($0.0.id, $0.1) })
    }
    
    var body: some View {
        ZStack {
            // Connection lines
            Canvas { context, size in
                for (_, link) in store.links {
                    guard let from = nodePositions[link.sourceID],
                          let to = nodePositions[link.targetID]
                    else { continue }
                    
                    var path = Path()
                    path.move(to: from)
                    path.addLine(to: to)
                    context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                }
            }
            
            // Nodes
            ForEach(layoutNodes, id: \.0.id) { node, position in
                GraphNode(node: node, isSelected: selectedNode?.id == node.id)
                    .position(position)
                    .onTapGesture { selectedNode = node }
            }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Graph Node

struct GraphNode: View {
    let node: MindNode
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: node.type.sfIcon)
                .font(.system(size: nodeSize))
            
            Text(node.title)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
                .frame(width: 60)
        }
        .padding(4)
        .background(
            Circle()
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
                .frame(width: nodeSize + 16, height: nodeSize + 16)
        )
        .overlay(
            Circle()
                .strokeBorder(
                    isSelected ? Color.accentColor : nodeColor.opacity(0.3),
                    lineWidth: isSelected ? 2 : 0.5
                )
                .frame(width: nodeSize + 16, height: nodeSize + 16)
        )
    }
    
    private var nodeSize: CGFloat {
        switch node.type {
        case .project: 24
        case .person: 18
        default: 14
        }
    }
    
    private var nodeColor: Color {
        node.type.color
    }
}
