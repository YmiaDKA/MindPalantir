import SwiftUI

/// Side inspector for viewing and editing a selected node.
struct InspectorPanel: View {
    @Environment(NodeStore.self) private var store
    let node: MindNode
    @State private var title: String
    @State private var nodeBody: String
    @State private var relevance: Double
    @State private var confidence: Double
    @State private var pinned: Bool
    @State private var status: NodeStatus

    init(node: MindNode) {
        self.node = node
        _title = State(initialValue: node.title)
        _nodeBody = State(initialValue: node.body)
        _relevance = State(initialValue: node.relevance)
        _confidence = State(initialValue: node.confidence)
        _pinned = State(initialValue: node.pinned)
        _status = State(initialValue: node.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(node.type.icon).font(.title)
                VStack(alignment: .leading) {
                    Text(node.type.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    Text(node.id.uuidString.prefix(8)).font(.caption2).foregroundStyle(.tertiary).monospaced()
                }
                Spacer()
                Toggle("Pin", isOn: $pinned).toggleStyle(.checkbox).labelsHidden()
            }

            Divider()

            // Editable fields
            TextField("Title", text: $title).font(.headline).textFieldStyle(.plain)
            TextField("Notes...", text: $nodeBody, axis: .vertical).textFieldStyle(.plain).lineLimit(3...8)

            // Status picker
            Picker("Status", selection: $status) {
                ForEach([NodeStatus.active, .completed, .archived, .draft, .waiting], id: \.self) { s in
                    Text(s.rawValue.capitalized).tag(s)
                }
            }.pickerStyle(.segmented)

            // Relevance & Confidence sliders
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Relevance").font(.caption)
                    Spacer()
                    Text("\(relevance, format: .percent.precision(.fractionLength(0)))").font(.caption).monospaced()
                }
                Slider(value: $relevance, in: 0...1)

                HStack {
                    Text("Confidence").font(.caption)
                    Spacer()
                    Text("\(confidence, format: .percent.precision(.fractionLength(0)))").font(.caption).monospaced()
                }
                Slider(value: $confidence, in: 0...1)
            }

            // Connected nodes
            let connected = store.connectedNodes(for: node.id)
            if !connected.isEmpty {
                Divider()
                Text("Connections (\(connected.count))").font(.caption).foregroundStyle(.secondary)
                ForEach(connected.prefix(5)) { c in
                    HStack {
                        Text(c.type.icon).font(.caption)
                        Text(c.title).font(.caption).lineLimit(1)
                        Spacer()
                        ConfidenceBadge(value: c.confidence)
                    }
                }
            }

            Divider()

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text("Created: \(node.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
                if let origin = node.sourceOrigin {
                    Text("Source: \(origin)").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Save
            Button("Save") { save() }.buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(minWidth: 260)
    }

    private func save() {
        var updated = node
        updated.title = title
        updated.body = nodeBody
        updated.relevance = relevance
        updated.confidence = confidence
        updated.pinned = pinned
        updated.status = status
        updated.updatedAt = .now
        try? store.insertNode(updated)
    }
}
