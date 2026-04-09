import SwiftUI

/// Card dashboard for a single project.
/// Wiki-inspired: each project is a living knowledge page.
/// Cards are interlinked, provenance is visible, knowledge compounds over time.
/// Inspired by Karpathy's LLM Wiki — the project IS the persistent artifact.
struct ProjectDetailView: View {
    @Environment(NodeStore.self) private var store
    let project: MindNode
    @Binding var selectedNode: MindNode?
    @State private var newTaskText = ""
    @State private var newNoteText = ""
    @State private var showConnections = false

    // MARK: - Derived Data

    private var tasks: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .task }
    }
    private var openTasks: [MindNode] {
        tasks.filter { $0.status != .completed }
            .sorted { $0.relevance > $1.relevance }
    }
    private var completedTasks: [MindNode] {
        tasks.filter { $0.status == .completed }
    }
    private var notes: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo)
            .filter { $0.type == .note }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    private var people: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo).filter { $0.type == .person }
    }
    private var events: [MindNode] {
        store.children(of: project.id, linkType: .belongsTo)
            .filter { $0.type == .event }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    private var sources: [MindNode] {
        store.children(of: project.id, linkType: .fromSource)
    }
    private var allConnected: [MindNode] {
        store.connectedNodes(for: project.id)
    }
    private var recentActivity: [MindNode] {
        // Recent notes + tasks for this project (updated in last 14 days)
        let cutoff = Date.now.addingTimeInterval(-14 * 86400)
        return (notes + tasks)
            .filter { $0.updatedAt > cutoff }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(6)
            .map { $0 }
    }

    /// Auto-discovered: nodes that mention the project title but aren't linked yet.
    /// This is the "living workspace" — the project finds related content on its own.
    private var discoveredNodes: [MindNode] {
        let linkedIDs = Set(allConnected.map(\.id) + [project.id])
        let terms = project.title.lowercased().split(separator: " ").filter { $0.count > 2 }
        guard !terms.isEmpty else { return [] }

        return store.nodes.values
            .filter { node in
                guard !linkedIDs.contains(node.id) else { return false }
                let text = (node.title + " " + node.body).lowercased()
                return terms.contains { text.contains($0) }
            }
            .sorted { $0.relevance > $1.relevance }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Watched Folder

    /// Path of the watched folder for this project (stored in metadata).
    private var watchedFolderPath: String? {
        project.metadata["watchedFolder"]
    }

    /// Files found in the watched folder.
    private var watchedFiles: [FileIngestor.FileInfo] {
        guard let path = watchedFolderPath else { return [] }
        let expanded = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return [] }

        let result = FileIngestor.scan(
            paths: [(expanded, "watched")],
            maxDepth: 2,
            maxFiles: 50
        )
        return result.files.sorted { $0.modified > $1.modified }
    }

    /// Watched files that are already imported as nodes (by path metadata).
    private var importedWatchedPaths: Set<String> {
        Set(store.nodes.values.compactMap { $0.metadata["path"] })
    }

    /// New files in watched folder not yet imported.
    private var newWatchedFiles: [FileIngestor.FileInfo] {
        watchedFiles.filter { !importedWatchedPaths.contains($0.path) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // Overview card — always at top
                overviewCard

                // Wiki synthesis — the "living knowledge" card
                // Shows what this project knows, not just what it contains
                synthesisCard

                // Connections mini-graph
                connectionsCard

                // Dashboard grid: two columns on wider screens
                AdaptiveCardGrid {
                    // Tasks card
                    if !tasks.isEmpty {
                        tasksCard
                    }

                    // Notes card
                    notesCard

                    // Activity card
                    if !recentActivity.isEmpty {
                        activityCard
                    }

                    // People card
                    if !people.isEmpty {
                        peopleCard
                    }

                    // Events card
                    if !events.isEmpty {
                        eventsCard
                    }

                    // Sources card
                    if !sources.isEmpty {
                        sourcesCard
                    }

                    // Auto-discovered card — content that mentions this project
                    if !discoveredNodes.isEmpty {
                        discoveredCard
                    }

                    // Watched folder card
                    watchedFolderCard

                    // Quick add card
                    quickAddCard
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle(project.title)
    }

    // MARK: - Overview Card (wiki-style hero)

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent gradient bar at top — like a wiki page header
            LinearGradient(
                colors: [Theme.Colors.accent.opacity(0.3), Theme.Colors.accent.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cardLarge))

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Title row
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Colors.typeColor(.project))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(project.title)
                            .font(.system(size: 26, weight: .bold, design: .default))
                            .lineLimit(2)

                        // Subtitle: status + confidence + last access
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(project.status.rawValue.capitalized)
                                .font(Theme.Fonts.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(statusColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(statusColor)

                            ConfidenceBadge(value: project.confidence)

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Text("Accessed \(project.lastAccessedAt, style: .relative)")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    // Pin toggle
                    Button {
                        var updated = project
                        updated.pinned.toggle()
                        updated.updatedAt = .now
                        try? store.insertNode(updated)
                    } label: {
                        Image(systemName: project.pinned ? "pin.fill" : "pin")
                            .font(.caption)
                            .foregroundStyle(project.pinned ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                    }
                    .buttonStyle(.plain)
                    .help(project.pinned ? "Unpin" : "Pin to Today")
                }

                // Description
                if !project.body.isEmpty {
                    Text(project.body)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                // Progress bar (full width)
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(completedTasks.count)/\(tasks.count) tasks")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(Double(completedTasks.count) / Double(tasks.count) * 100))%")
                                .font(Theme.Fonts.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.quaternary)
                                Capsule()
                                    .fill(completedTasks.count == tasks.count ? .green : Theme.Colors.accent.opacity(0.6))
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                        .frame(height: 6)
                    }
                }

                // Stats row
                HStack(spacing: Theme.Spacing.lg) {
                    statLabel("\(allConnected.count)", icon: "link", label: "connected")
                    statLabel("\(tasks.count)", icon: "checklist", label: "tasks")
                    statLabel("\(notes.count)", icon: "note.text", label: "notes")
                    statLabel("\(sources.count)", icon: "link", label: "sources")

                    Spacer()

                    Text("Updated \(project.updatedAt, style: .relative)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.cardLarge)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .shadow(color: Theme.Shadow.hero.color, radius: Theme.Shadow.hero.radius, y: Theme.Shadow.hero.y)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.cardLarge)
                .strokeBorder(Theme.Colors.accent.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedTasks.count) / Double(tasks.count)
    }

    private var statusColor: Color {
        switch project.status {
        case .active: .green
        case .completed: .blue
        case .archived: .secondary
        case .draft: .orange
        case .waiting: .yellow
        }
    }

    private func statLabel(_ value: String, icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
            Text(label)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Synthesis Card (wiki-inspired — what this project KNOWS)

    private var synthesisCard: some View {
        let allContent = notes + tasks + people + events
        let totalWords = allContent.reduce(0) { count, node in
            count + node.title.count + node.body.count
        }
        let types = Set(allContent.map { $0.type })

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "brain")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.accent)
                Text("Knowledge Synthesis")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                Text("\(allContent.count) nodes · ~\(totalWords) chars")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
            }

            // What this project covers — type distribution as a visual bar
            if !types.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(types).sorted { $0.rawValue < $1.rawValue }, id: \.self) { type in
                        let count = allContent.filter { $0.type == type }.count
                        let ratio = Double(count) / Double(allContent.count)
                        if ratio > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Colors.typeColor(type).opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .frame(height: 6)
                                .overlay(alignment: .center) {
                                    if ratio > 0.15 {
                                        Text(type.rawValue.prefix(1).uppercased())
                                            .font(.system(size: 7, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                        }
                    }
                }
                .frame(height: 6)
            }

            // Key entities — what names/concepts appear across this project
            if !project.body.isEmpty {
                Text(project.body)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Provenance: when was knowledge last added?
            if let newest = allContent.max(by: { $0.updatedAt < $1.updatedAt }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text("Last updated \(newest.updatedAt, style: .relative) · \(newest.title)")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spatialCard(shadow: Theme.Shadow.card)
    }

    // MARK: - Connections Card (mini-graph)

    private var connectionsCard: some View {
        let connected = allConnected
        let byType = Dictionary(grouping: connected) { $0.type }

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.accent)
                Text("Connections")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                Text("\(connected.count)")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                Button(showConnections ? "Collapse" : "Expand") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showConnections.toggle()
                    }
                }
                .font(Theme.Fonts.tiny)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.accent)
            }

            // Type distribution dots — quick visual
            HStack(spacing: Theme.Spacing.md) {
                ForEach(NodeType.allCases, id: \.self) { type in
                    let nodes = byType[type] ?? []
                    if !nodes.isEmpty {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Theme.Colors.typeColor(type))
                                .frame(width: 8, height: 8)
                            Text("\(nodes.count)")
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }

            if showConnections {
                Divider()
                // Connection list
                ForEach(connected.prefix(8)) { node in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: node.type.sfIcon)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.typeColor(node.type))
                            .frame(width: 14)
                        Text(node.title)
                            .font(Theme.Fonts.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(node.type.rawValue)
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 1)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = node }
                }
                if connected.count > 8 {
                    Text("+ \(connected.count - 8) more")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spatialCard(shadow: Theme.Shadow.card)
    }

    // MARK: - Tasks Card

    private var tasksCard: some View {
        DashboardCard(title: "Tasks", icon: "checklist", count: tasks.count) {
            VStack(spacing: 1) {
                // Show open tasks first, then up to 3 completed
                let displayTasks = openTasks + completedTasks.prefix(3)
                ForEach(displayTasks) { task in
                    taskRow(task)
                }

                if completedTasks.count > 3 {
                    Text("+ \(completedTasks.count - 3) more completed")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }

                // Inline quick add
                Divider().padding(.vertical, Theme.Spacing.xs)
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.accent)
                    TextField("Add task...", text: $newTaskText)
                        .font(Theme.Fonts.body)
                        .textFieldStyle(.plain)
                        .onSubmit { addQuickTask() }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func taskRow(_ task: MindNode) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { toggleTask(task) } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(task.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(Theme.Fonts.body)
                .lineLimit(1)
                .strikethrough(task.status == .completed)
                .foregroundStyle(task.status == .completed ? .secondary : .primary)

            Spacer()

            if let due = task.dueDate {
                Text(due, style: .relative)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(due < Date() ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
            }

            Circle()
                .fill(Theme.Colors.relevance(task.relevance))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { selectedNode = task }
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        DashboardCard(title: "Notes", icon: "note.text", count: notes.count) {
            VStack(spacing: Theme.Spacing.xs) {
                if notes.isEmpty {
                    Text("No notes yet")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(notes.prefix(5)) { note in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.typeColor(.note))
                                .frame(width: 14)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(note.title)
                                    .font(Theme.Fonts.body)
                                    .lineLimit(1)
                                if !note.body.isEmpty {
                                    Text(note.body)
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Text(note.updatedAt, style: .relative)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNode = note }
                    }

                    if notes.count > 5 {
                        Text("+ \(notes.count - 5) more")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Inline quick add
                Divider().padding(.vertical, Theme.Spacing.xs)
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.accent)
                    TextField("Add note...", text: $newNoteText)
                        .font(Theme.Fonts.body)
                        .textFieldStyle(.plain)
                        .onSubmit { addQuickNote() }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        DashboardCard(title: "Recent Activity", icon: "clock", count: recentActivity.count) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(recentActivity) { node in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: node.type.sfIcon)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.typeColor(node.type))
                            .frame(width: 16)

                        Text(node.title)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)

                        Spacer()

                        Text(node.updatedAt, style: .relative)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = node }
                }
            }
        }
    }

    // MARK: - People Card

    private var peopleCard: some View {
        DashboardCard(title: "People", icon: "person.2", count: people.count) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(people) { person in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Colors.typeColor(.person))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(person.title)
                                .font(Theme.Fonts.body)
                                .lineLimit(1)
                            if !person.body.isEmpty {
                                Text(person.body)
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = person }
                }
            }
        }
    }

    // MARK: - Events Card

    private var eventsCard: some View {
        DashboardCard(title: "Events", icon: "calendar", count: events.count) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(events) { event in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.typeColor(.event))

                        Text(event.title)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)

                        Spacer()

                        if let due = event.dueDate {
                            Text(due, style: .relative)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(due < Date() ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                        }
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = event }
                }
            }
        }
    }

    // MARK: - Sources Card

    private var sourcesCard: some View {
        DashboardCard(title: "Sources", icon: "link", count: sources.count) {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(sources) { source in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.typeColor(.source))

                        Text(source.title)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)

                        Spacer()

                        ConfidenceBadge(value: source.confidence)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = source }
                }
            }
        }
    }

    // MARK: - Discovered Card (auto-related content)

    private var discoveredCard: some View {
        DashboardCard(title: "Related", icon: "sparkles", count: discoveredNodes.count) {
            VStack(spacing: Theme.Spacing.xs) {
                Text("Mentions \"\(project.title)\" but not yet linked")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(discoveredNodes) { node in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: node.type.sfIcon)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.typeColor(node.type))
                            .frame(width: 16)

                        Text(node.title)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)

                        Spacer()

                        // One-click link button
                        Button { linkNode(node) } label: {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Link to project")
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedNode = node }
                }
            }
        }
    }

    // MARK: - Watched Folder Card

    private var watchedFolderCard: some View {
        DashboardCard(
            title: watchedFolderPath != nil ? "Watched Folder" : "Watch Folder",
            icon: "eye",
            count: watchedFiles.count,
            showCount: watchedFolderPath != nil
        ) {
            if let folderPath = watchedFolderPath {
                // Folder is set — show files
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    // Path with change button
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text((folderPath as NSString).lastPathComponent)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button("Change") { selectWatchedFolder() }
                            .font(Theme.Fonts.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.Colors.accent)
                    }

                    // New files (not yet imported)
                    if !newWatchedFiles.isEmpty {
                        Text("\(newWatchedFiles.count) new files")
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.top, 2)

                        ForEach(newWatchedFiles.prefix(5)) { file in
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: iconForExt(file.ext))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                Text(file.name)
                                    .font(Theme.Fonts.body)
                                    .lineLimit(1)
                                Spacer()
                                Button { importFile(file) } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.Colors.accent)
                                }
                                .buttonStyle(.plain)
                                .help("Import to project")
                            }
                            .padding(.vertical, 2)
                        }

                        if newWatchedFiles.count > 5 {
                            Button("Import all \(newWatchedFiles.count) files") {
                                importAllNewFiles()
                            }
                            .font(Theme.Fonts.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(Theme.Colors.accent)
                        }
                    } else {
                        Text("All files imported")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                // No folder set — prompt to set one
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Point this project at a folder to auto-import files")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button { selectWatchedFolder() } label: {
                        Label("Choose Folder", systemImage: "folder.badge.plus")
                            .font(Theme.Fonts.body)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Theme.Colors.accent)
                }
            }
        }
    }

    private func selectWatchedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for this project to watch"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            var updated = project
            var meta = updated.metadata
            meta["watchedFolder"] = url.path
            updated.metadata = meta
            updated.updatedAt = .now
            try? store.insertNode(updated)
        }
    }

    private func importFile(_ file: FileIngestor.FileInfo) {
        // Dedup: skip if path already imported
        guard !importedWatchedPaths.contains(file.path) else { return }

        let node = MindNode(
            type: .source,
            title: file.name,
            body: "\(file.path)\n\(file.ext.uppercased()) · \(formatSize(file.size))",
            relevance: 0.7,
            confidence: 0.9,
            sourceOrigin: "watched_folder",
            metadata: ["path": file.path, "ext": file.ext]
        )
        try? store.insertNode(node)

        let link = MindLink(
            sourceID: project.id,
            targetID: node.id,
            linkType: .fromSource
        )
        try? store.insertLink(link)
    }

    private func importAllNewFiles() {
        for file in newWatchedFiles {
            importFile(file)
        }
    }

    private func iconForExt(_ ext: String) -> String {
        switch ext {
        case "swift", "py", "js", "ts", "rs", "go": "chevron.left.forwardslash.chevron.right"
        case "md", "txt", "org": "doc.text"
        case "pdf": "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": "photo"
        case "json", "yaml", "yml", "toml": "curlybraces"
        case "csv", "tsv": "tablecells"
        default: "doc"
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB]
        return f.string(fromByteCount: bytes)
    }

    // MARK: - Quick Add Card

    private var quickAddCard: some View {
        DashboardCard(title: "Add", icon: "plus.circle", showCount: false) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach([NodeType.task, .note, .person, .event, .source], id: \.self) { type in
                    Button { addLinkedNode(type: type) } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: type.sfIcon)
                                .frame(width: 16)
                            Text(type.rawValue.capitalized)
                            Spacer()
                            Image(systemName: "plus")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .font(Theme.Fonts.body)
                        .padding(.vertical, 4)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleTask(_ node: MindNode) {
        var updated = node
        updated.status = node.status == .completed ? .active : .completed
        updated.updatedAt = .now
        try? store.insertNode(updated)
    }

    private func addQuickTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = MindNode(type: .task, title: trimmed, sourceOrigin: "project_add")
        try? store.insertNode(task)

        let link = MindLink(sourceID: project.id, targetID: task.id, linkType: .belongsTo)
        try? store.insertLink(link)

        newTaskText = ""
    }

    private func addQuickNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let note = MindNode(type: .note, title: trimmed, sourceOrigin: "project_add")
        try? store.insertNode(note)

        let link = MindLink(sourceID: project.id, targetID: note.id, linkType: .belongsTo)
        try? store.insertLink(link)

        newNoteText = ""
    }

    /// Link an existing node to this project (from discovered/related)
    private func linkNode(_ node: MindNode) {
        let link = MindLink(
            sourceID: project.id,
            targetID: node.id,
            linkType: .relatedTo
        )
        try? store.insertLink(link)
    }

    private func addLinkedNode(type: NodeType) {
        let node = MindNode(
            type: type,
            title: "New \(type.rawValue)",
            sourceOrigin: "project_add"
        )
        try? store.insertNode(node)

        let link = MindLink(
            sourceID: project.id,
            targetID: node.id,
            linkType: type == .source ? .fromSource : .belongsTo
        )
        try? store.insertLink(link)
    }
}

// MARK: - Dashboard Card (reusable panel)

struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    var count: Int = 0
    var showCount: Bool = true
    @State private var isHovered = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Card header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(.primary)
                if showCount {
                    Text("\(count)")
                        .font(Theme.Fonts.tiny)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
            }

            content()
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .spatialCard(
            shadow: isHovered ? Theme.Shadow.elevated : Theme.Shadow.card,
            radius: Theme.Radius.card
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Adaptive Card Grid

/// Two-column grid on wider views, single column on narrow.
/// Uses LazyVGrid so cards fill naturally.
struct AdaptiveCardGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: Theme.Spacing.md),
            GridItem(.flexible(), spacing: Theme.Spacing.md),
        ]
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            content()
        }
    }
}
