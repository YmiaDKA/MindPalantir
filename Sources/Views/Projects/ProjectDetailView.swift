import SwiftUI

/// Card dashboard for a single project.
/// Each section is a self-contained card panel — feels like a living workspace, not a flat list.
struct ProjectDetailView: View {
    @Environment(NodeStore.self) private var store
    let project: MindNode
    @Binding var selectedNode: MindNode?

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

                // Dashboard grid: two columns on wider screens
                AdaptiveCardGrid {
                    // Tasks card
                    if !tasks.isEmpty {
                        tasksCard
                    }

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

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Title row
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Colors.typeColor(.project))

                Text(project.title)
                    .font(Theme.Fonts.largeTitle)
                    .lineLimit(2)

                Spacer()

                // Status pill
                Text(project.status.rawValue.capitalized)
                    .font(Theme.Fonts.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(statusColor)

                ConfidenceBadge(value: project.confidence)
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
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.accent.opacity(0.12), lineWidth: 1)
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
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
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
