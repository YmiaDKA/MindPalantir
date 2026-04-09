import Foundation

/// Watches directories for new/changed files and auto-imports them.
/// Uses FSEvents for efficient monitoring.
@MainActor
final class WatcherService {
    private var stream: FSEventStreamRef?
    private let store: NodeStore
    private var watchedPaths: [String] = []
    private var lastScan: Date = .distantPast
    
    init(store: NodeStore) {
        self.store = store
    }
    
    // MARK: - Start Watching
    
    func start(paths: [String] = [
        NSString(string: "~/Desktop").expandingTildeInPath,
        NSString(string: "~/Documents").expandingTildeInPath,
        NSString(string: "~/Downloads").expandingTildeInPath,
    ]) {
        watchedPaths = paths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !watchedPaths.isEmpty else {
            print("👁️ No valid paths to watch")
            return
        }
        
        // Use a timer-based approach instead of FSEvents for simplicity
        // FSEvents callbacks have actor isolation issues
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanForNewFiles()
            }
        }
        
        // Also scan once on start
        scanForNewFiles()
        
        print("👁️ Watching \(watchedPaths.count) directories for changes (30s interval)")
    }
    
    // MARK: - Scan
    
    private func scanForNewFiles() {
        let now = Date()
        guard now.timeIntervalSince(lastScan) > 10 else { return }
        lastScan = now

        let result = FileIngestor.scan(maxDepth: 1, maxFiles: 20)

        // Only import files we haven't seen before
        let existingPaths = Set(store.nodes.values.compactMap { $0.metadata["path"] })
        let newFiles = result.files.filter { !existingPaths.contains($0.path) }

        guard !newFiles.isEmpty else { return }

        var imported = 0
        for file in newFiles.prefix(5) {
            let nodeType = classifyFileType(file)
            let body = readPreview(path: file.path, maxChars: 500)
            let node = MindNode(
                type: nodeType,
                title: file.name,
                body: body.isEmpty ? "New file: \(file.path)" : body,
                relevance: 0.7,
                confidence: nodeType == .source ? 0.9 : 0.7,
                sourceOrigin: "file_watcher",
                metadata: ["path": file.path, "ext": file.ext]
            )
            try? store.insertNode(node)
            autoLinkToProjects(node: node)
            imported += 1
        }

        if imported > 0 {
            print("👁️ Auto-imported \(imported) new files")
        }
    }

    /// Read a preview of text file contents.
    private func readPreview(path: String, maxChars: Int) -> String {
        let textExts: Set<String> = ["md", "txt", "org", "tex", "rst", "json", "yaml", "yml", "toml", "csv", "swift", "py", "js", "ts", "html", "css", "sh"]
        let ext = (path as NSString).pathExtension.lowercased()
        guard textExts.contains(ext) else { return "" }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .utf8)
        else { return "" }
        return String(content.prefix(maxChars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Classify file into a node type based on extension and name patterns.
    private func classifyFileType(_ file: FileIngestor.FileInfo) -> NodeType {
        let name = file.name.lowercased()

        // Task files
        if name.contains("todo") || name.contains("task") || name.contains("backlog") {
            return .task
        }

        // Notes — markdown, text, org
        if ["md", "txt", "org", "tex", "rst"].contains(file.ext) {
            return .note
        }

        // Person — vcard
        if file.ext == "vcf" {
            return .person
        }

        // Event — calendar files
        if ["ics", "ical"].contains(file.ext) {
            return .event
        }

        // Everything else → source
        return .source
    }

    /// Auto-link a newly imported node to any project whose title it mentions.
    /// This is the bridge between ingestion and the living workspace.
    private func autoLinkToProjects(node: MindNode) {
        let text = (node.title + " " + node.body).lowercased()
        let projects = store.nodes.values.filter { $0.type == .project }

        for project in projects {
            let terms = project.title.lowercased().split(separator: " ").filter { $0.count > 2 }
            guard !terms.isEmpty else { continue }

            if terms.contains(where: { text.contains($0) }) {
                // Check not already linked
                if !store.linkExists(sourceID: project.id, targetID: node.id, type: .fromSource) {
                    let link = MindLink(
                        sourceID: project.id,
                        targetID: node.id,
                        linkType: .fromSource
                    )
                    try? store.insertLink(link)
                    print("🔗 Auto-linked \(node.title) → \(project.title)")
                }
            }
        }
    }
}
