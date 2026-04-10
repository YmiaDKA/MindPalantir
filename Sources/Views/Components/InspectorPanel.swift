import SwiftUI

/// Clean inspector panel — right side drawer.
/// Apple HIG: 300pt width, non-blocking, shows details of selected item.
struct InspectorPanel: View {
    @Environment(NodeStore.self) private var store
    let node: MindNode
    @State private var title: String
    @State private var nodeBody: String
    @State private var relevance: Double
    @State private var confidence: Double
    @State private var pinned: Bool
    @State private var status: NodeStatus
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    @State private var showSaveConfirmation = false
    @State private var saveTimer: Timer?
    @FocusState private var bodyFieldFocused: Bool

    // Create Link state
    @State private var linkSearchText = ""
    @State private var selectedLinkType: LinkType = .relatedTo
    @State private var showLinkSearch = false
    @State private var linkCreatedFeedback = false

    init(node: MindNode) {
        self.node = node
        _title = State(initialValue: node.title)
        _nodeBody = State(initialValue: node.body)
        _relevance = State(initialValue: node.relevance)
        _confidence = State(initialValue: node.confidence)
        _pinned = State(initialValue: node.pinned)
        _status = State(initialValue: node.status)
        _dueDate = State(initialValue: node.dueDate)
        _hasDueDate = State(initialValue: node.dueDate != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // Type + Pin
                headerSection
                
                // Editable fields
                fieldsSection
                
                // Status pills
                statusSection
                
                // Due Date (for tasks/events)
                if node.type == .task || node.type == .event {
                    dueDateSection
                }

                // Scores
                scoresSection
                
                // Connections
                connectionsSection

                // Backlinks — nodes that reference this one
                backlinksSection
                
                // Create Link — explicitly connect this node to another
                createLinkSection

                // Metadata
                metadataSection
                
                // Delete
                Divider()
                deleteButton

                // Auto-save indicator
                if showSaveConfirmation {
                    HStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.green)
                        Text("Saved")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .frame(minWidth: 280, idealWidth: 300)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .onChange(of: title) { _, _ in debouncedSave() }
        .onChange(of: nodeBody) { _, _ in debouncedSave() }
        .onChange(of: relevance) { _, _ in debouncedSave() }
        .onChange(of: confidence) { _, _ in debouncedSave() }
        .onChange(of: pinned) { _, _ in debouncedSave() }
        .onChange(of: status) { _, _ in debouncedSave() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusBodyEditor"))) { _ in
            bodyFieldFocused = true
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: node.type.sfIcon)
                .font(.system(size: 24))
            
            Text(node.type.rawValue.uppercased())
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)
            
            Spacer()
            
            Button { pinned.toggle() } label: {
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .foregroundStyle(pinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Fields
    
    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            TextField("Title", text: $title, axis: .vertical)
                .font(Theme.Fonts.headline)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
            
            Divider()
            
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                TextField("Add notes...", text: $nodeBody, axis: .vertical)
                    .font(Theme.Fonts.body)
                    .textFieldStyle(.plain)
                    .lineLimit(3...10)
                    .foregroundStyle(.secondary)
                    .focused($bodyFieldFocused)
                    .help("Edit body (⌘E)")

                if !bodyFieldFocused {
                    Text("⌘E")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                        .padding(.top, 2)
                }
            }
        }
    }
    
    // MARK: - Status
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("STATUS")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)
            
            HStack(spacing: 6) {
                ForEach([NodeStatus.active, .completed, .archived, .draft, .waiting], id: \.self) { s in
                    Button { status = s } label: {
                        Text(s.rawValue.capitalized)
                            .font(Theme.Fonts.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                status == s ? Theme.Colors.accent.opacity(0.15) : Color.clear,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
                            )
                            .foregroundStyle(status == s ? Theme.Colors.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Due Date

    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("DUE DATE")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)

            HStack(spacing: Theme.Spacing.sm) {
                Toggle(isOn: $hasDueDate) {
                    Text("Set due date")
                        .font(Theme.Fonts.caption)
                }
                .toggleStyle(.checkbox)
            }

            if hasDueDate {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
        }
        .onChange(of: hasDueDate) { _, newValue in
            if !newValue { dueDate = nil }
            else if dueDate == nil { dueDate = Date() }
            debouncedSave()
        }
        .onChange(of: dueDate) { _, _ in debouncedSave() }
    }

    // MARK: - Scores
    
    private var scoresSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("SCORES")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)
            
            scoreSlider(label: "Relevance", value: $relevance, color: Theme.Colors.relevance(relevance))
            scoreSlider(label: "Confidence", value: $confidence, color: Theme.Colors.confidence(confidence))
        }
    }
    
    private func scoreSlider(label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(Theme.Fonts.caption)
                    .monospaced()
                    .foregroundStyle(color)
            }
            
            Slider(value: value, in: 0...1)
                .tint(color)
                .labelsHidden()
        }
    }
    
    // MARK: - Connections
    
    private var connectionsSection: some View {
        let connected = store.connectedNodes(for: node.id)
        return Group {
            if !connected.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("CONNECTIONS (\(connected.count))")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                    
                    VStack(spacing: 2) {
                        ForEach(connected.prefix(8)) { c in
                            HStack(spacing: Theme.Spacing.sm) {
                                Circle()
                                    .fill(Theme.Colors.typeColor(c.type))
                                    .frame(width: 6, height: 6)
                                Text(c.title)
                                    .font(Theme.Fonts.caption)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SelectNode"),
                                    object: c
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Backlinks (wiki essential — what links here?)

    private var backlinksSection: some View {
        let allBacklinks = store.backlinks(for: node.id)
        // Filter out "connections" (bidirectional) — backlinks are INCOMING only
        // connectionsSection already shows all connected nodes, so backlinks emphasizes
        // the directionality and link type for wiki-style navigation
        let byType = Dictionary(grouping: allBacklinks) { $0.linkType }

        return Group {
            if !allBacklinks.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("BACKLINKS")
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.tertiary)
                            .tracking(1)
                        Spacer()
                        Text("\(allBacklinks.count)")
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }

                    // Show backlinks grouped by link type for clarity
                    ForEach(LinkType.allCases, id: \.self) { linkType in
                        let items = byType[linkType] ?? []
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                // Link type label
                                Text(linkTypeLabel(linkType))
                                    .font(Theme.Fonts.tiny)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 2)

                                ForEach(items, id: \.node.id) { entry in
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Image(systemName: entry.node.type.sfIcon)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.Colors.typeColor(entry.node.type))
                                            .frame(width: 14)
                                        Text(entry.node.title)
                                            .font(Theme.Fonts.caption)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "arrow.turn.down.right")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .padding(.vertical, 4)
                                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("SelectNode"),
                                            object: entry.node
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func linkTypeLabel(_ type: LinkType) -> String {
        switch type {
        case .belongsTo: "belongs to"
        case .relatedTo: "related"
        case .mentions: "mentions"
        case .scheduledFor: "scheduled"
        case .fromSource: "from source"
        }
    }

    // MARK: - Create Link

    /// Search results for linking — excludes self and already-connected nodes
    private var linkSearchResults: [MindNode] {
        guard !linkSearchText.isEmpty else { return [] }
        let query = linkSearchText.lowercased()
        let connectedIDs = Set(store.connectedNodes(for: node.id).map(\.id))
        return store.nodes.values
            .filter { $0.id != node.id && !connectedIDs.contains($0.id) }
            .filter { $0.title.lowercased().contains(query) || $0.body.lowercased().contains(query) }
            .sorted { $0.relevance > $1.relevance }
            .prefix(5)
            .map { $0 }
    }

    private var createLinkSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("CREATE LINK")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                Spacer()
                if linkCreatedFeedback {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                        Text("Linked")
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }

            // Link type picker
            HStack(spacing: 4) {
                ForEach(LinkType.allCases, id: \.self) { linkType in
                    Button { selectedLinkType = linkType } label: {
                        Text(linkTypeLabel(linkType))
                            .font(Theme.Fonts.tiny)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                selectedLinkType == linkType
                                    ? Theme.Colors.accent.opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .foregroundStyle(selectedLinkType == linkType ? AnyShapeStyle(Theme.Colors.accent) : AnyShapeStyle(.tertiary))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Search field
            HStack(spacing: 4) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                TextField("Search nodes to link...", text: $linkSearchText)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.caption)
                    .onChange(of: linkSearchText) { _, _ in
                        showLinkSearch = !linkSearchText.isEmpty
                    }
                if !linkSearchText.isEmpty {
                    Button {
                        linkSearchText = ""
                        showLinkSearch = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))

            // Search results
            if showLinkSearch && !linkSearchResults.isEmpty {
                VStack(spacing: 1) {
                    ForEach(linkSearchResults) { candidate in
                        Button { createLink(to: candidate) } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: candidate.type.sfIcon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.Colors.typeColor(candidate.type))
                                    .frame(width: 14)
                                Text(candidate.title)
                                    .font(Theme.Fonts.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.Colors.accent)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }

    private func createLink(to target: MindNode) {
        guard !store.linkExists(sourceID: node.id, targetID: target.id, type: selectedLinkType) else { return }
        let link = MindLink(sourceID: node.id, targetID: target.id, linkType: selectedLinkType)
        try? store.insertLink(link)
        linkSearchText = ""
        showLinkSearch = false
        withAnimation { linkCreatedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { linkCreatedFeedback = false }
        }
    }

    // MARK: - Metadata
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("INFO")
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
                .tracking(1)
            
            VStack(alignment: .leading, spacing: 3) {
                metaRow(icon: "clock", text: "Created " + node.createdAt.formatted(date: .abbreviated, time: .shortened))
                metaRow(icon: "pencil", text: "Updated " + node.updatedAt.formatted(date: .abbreviated, time: .shortened))
                metaRow(icon: "eye", text: "Viewed \(node.accessCount) times")
                if node.accessCount > 0 {
                    metaRow(icon: "clock.arrow.circlepath", text: "Last viewed " + node.lastAccessedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let origin = node.sourceOrigin {
                    metaRow(icon: "arrow.triangle.branch", text: "Via " + origin)
                }
                if let due = node.dueDate {
                    metaRow(icon: "calendar", text: due.formatted(date: .abbreviated, time: .omitted))
                }
                // Parent project
                if let project = parentProject {
                    metaRow(icon: "folder", text: project.title)
                }

                // Open URL button for source nodes
                if node.type == .source, let urlString = extractURL(from: node) {
                    Button {
                        if let url = URL(string: urlString) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.accent)
                                .frame(width: 12)
                            Text("Open URL")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func extractURL(from node: MindNode) -> String? {
        let text = node.title + " " + node.body
        if text.contains("http://") || text.contains("https://") {
            let components = text.components(separatedBy: .whitespacesAndNewlines)
            return components.first { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
        }
        return nil
    }
    
    private var parentProject: MindNode? {
        store.links.values
            .filter { $0.targetID == node.id && $0.linkType == .belongsTo }
            .compactMap { store.nodes[$0.sourceID] }
            .first { $0.type == .project }
    }
    
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 12)
            Text(text)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            try? store.deleteNode(id: node.id)
        } label: {
            HStack {
                Spacer()
                Image(systemName: "trash")
                Text("Delete")
                Spacer()
            }
            .font(Theme.Fonts.body)
            .padding(.vertical, 8)
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Auto-Save

    private func debouncedSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                save()
            }
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
        updated.dueDate = dueDate
        updated.updatedAt = .now
        try? store.insertNode(updated)
        withAnimation { showSaveConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSaveConfirmation = false }
        }
    }
}
