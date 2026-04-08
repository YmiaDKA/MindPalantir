import SwiftUI

/// Clean inspector panel — right side drawer.
struct InspectorPanel: View {
    @Environment(NodeStore.self) private var store
    let node: MindNode
    @State private var title: String
    @State private var nodeBody: String
    @State private var relevance: Double
    @State private var confidence: Double
    @State private var pinned: Bool
    @State private var status: NodeStatus
    @State private var showSaveConfirmation = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Type + Title
                headerSection
                
                // Editable fields
                fieldsSection
                
                // Status
                statusSection
                
                // Scores
                scoresSection
                
                // Connections
                connectionsSection
                
                // Metadata
                metadataSection
                
                // Save
                saveButton
            }
            .padding(20)
        }
        .frame(minWidth: 280, idealWidth: 320)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(node.type.icon)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text("#\(node.id.uuidString.prefix(6))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospaced()
                }
                Spacer()
                Button {
                    pinned.toggle()
                } label: {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .foregroundStyle(pinned ? .orange : .secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $title, axis: .vertical)
                .font(.headline)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
            
            Divider()
            
            TextField("Add notes...", text: $nodeBody, axis: .vertical)
                .font(.body)
                .textFieldStyle(.plain)
                .lineLimit(3...10)
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach([NodeStatus.active, .completed, .archived, .draft, .waiting], id: \.self) { s in
                        Button {
                            status = s
                        } label: {
                            Text(shortLabel(for: s))
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    status == s ? Color.accentColor.opacity(0.2) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .foregroundStyle(status == s ? .primary : .secondary)
                                .fixedSize()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var scoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scores")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            VStack(spacing: 10) {
                scoreRow(label: "Relevance", value: $relevance, color: .green)
                scoreRow(label: "Confidence", value: $confidence, color: .orange)
            }
        }
    }
    
    private func scoreRow(label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value.wrappedValue, format: .percent.precision(.fractionLength(0)))")
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.6))
                        .frame(width: geo.size.width * value.wrappedValue, height: 4)
                }
            }
            .frame(height: 4)
            Slider(value: value, in: 0...1)
                .labelsHidden()
        }
    }
    
    private var connectionsSection: some View {
        let connected = store.connectedNodes(for: node.id)
        return Group {
            if !connected.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connections (\(connected.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    VStack(spacing: 4) {
                        ForEach(connected.prefix(8)) { c in
                            HStack(spacing: 8) {
                                Text(c.type.icon)
                                    .font(.system(size: 12))
                                Text(c.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                ConfidenceBadge(value: c.confidence)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Info")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            VStack(alignment: .leading, spacing: 4) {
                metaRow(icon: "clock", text: node.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let origin = node.sourceOrigin {
                    metaRow(icon: "arrow.triangle.branch", text: origin)
                }
                if let due = node.dueDate {
                    metaRow(icon: "calendar", text: due.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
    }
    
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 12)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack {
                Spacer()
                Text("Save Changes")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if showSaveConfirmation {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func shortLabel(for status: NodeStatus) -> String {
        switch status {
        case .active: "Active"
        case .completed: "Done"
        case .archived: "Archived"
        case .draft: "Draft"
        case .waiting: "Waiting"
        }
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
        withAnimation {
            showSaveConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSaveConfirmation = false
            }
        }
    }
}
