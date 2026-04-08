import Foundation

/// Scans the Mac and populates MindPalantir with real data.
/// This is the "brain ingester" — makes the app useful immediately.
@MainActor
final class DataSeeder {

    /// Seed the database with real data from this Mac.
    static func seed(store: NodeStore) async {
        // Only seed if empty
        guard store.nodes.isEmpty else { return }

        print("🧠 Seeding MindPalantir with real data...")

        // 1. Create the MindPalantir project
        let mpProject = MindNode(
            type: .project,
            title: "MindPalantir",
            body: "The second brain app — native macOS SwiftUI with SQLite graph storage, relevance scoring, and Hermes integration.",
            relevance: 0.95,
            confidence: 0.95,
            status: .active,
            pinned: true,
            sourceOrigin: "auto_seed"
        )
        try? store.insertNode(mpProject)

        // 2. Create project tasks
        let taskData: [(String, String, NodeStatus)] = [
            ("Build project drill-down view", "Show linked tasks, notes, people, events for each project", .completed),
            ("Implement relevance scoring", "Combine recency, access, links, pinned status into 0-1 score", .completed),
            ("Add confidence system", "Track source quality, classification certainty, link strength", .completed),
            ("Build Today/Desktop view", "Curated relevance-ranked cards showing what matters now", .completed),
            ("Create Quick Add capture", "Chat-like input for fast node creation", .completed),
            ("Add SQLite persistence", "Single source of truth with WAL mode, foreign keys, dedup", .completed),
            ("Set up MCP servers", "sosumi.ai for Apple docs, ShipSwift for UI, XcodeBuildMCP for builds", .completed),
            ("Install Apple dev skills", "24+ skills: SwiftUI, StoreKit, Charts, SwiftData, concurrency", .completed),
            ("Build Hermes ingestion", "Hermes reads data from Mac and creates nodes automatically", .active),
            ("File watcher for inbox", "Watch folders for new files, auto-import to inbox", .active),
            ("Weekly review / resurfacing", "Surface stale but useful items periodically", .draft),
            ("Gmail/Calendar integration", "Import emails and events as nodes", .draft),
        ]

        for (title, body, status) in taskData {
            let task = MindNode(
                type: .task,
                title: title,
                body: body,
                relevance: status == .completed ? 0.3 : (status == .active ? 0.7 : 0.4),
                confidence: 0.9,
                status: status,
                sourceOrigin: "auto_seed"
            )
            try? store.insertNode(task)
            let link = MindLink(sourceID: mpProject.id, targetID: task.id, linkType: .belongsTo)
            try? store.insertLink(link)
        }

        // 3. Scan for real files on this Mac
        await seedFromFiles(store: store, projectID: mpProject.id)

        // 4. Scan git repos
        await seedFromGitRepos(store: store, projectID: mpProject.id)

        // 5. Scan homebrew packages
        await seedFromHomebrew(store: store)

        // 6. Create a "Development" project for this Mac setup
        let devProject = MindNode(
            type: .project,
            title: "MacBook Air Dev Setup",
            body: "M1 MacBook Air running macOS 26.4 with Hermes Agent, XcodeBuildMCP, and local AI models.",
            relevance: 0.7,
            confidence: 0.9,
            status: .active,
            sourceOrigin: "auto_seed"
        )
        try? store.insertNode(devProject)

        // Link dev project to MindPalantir
        try? store.insertLink(MindLink(sourceID: devProject.id, targetID: mpProject.id, linkType: .relatedTo))

        // 7. Create people from conversation context
        let ibrahim = MindNode(
            type: .person,
            title: "Ibrahim",
            body: "Lead developer. Building MindPalantir on MacBook Air M1. Uses Hermes Agent + Codex for development.",
            relevance: 0.95,
            confidence: 0.95,
            pinned: true,
            sourceOrigin: "auto_seed"
        )
        try? store.insertNode(ibrahim)

        // Link Ibrahim to project
        try? store.insertLink(MindLink(sourceID: mpProject.id, targetID: ibrahim.id, linkType: .mentions))

        // 8. Create sources from known tools/tech
        let sources: [(String, String)] = [
            ("Hermes Agent v0.8.0", "AI orchestrator running on the Mac. Handles research, planning, code generation, tool orchestration."),
            ("XcodeBuildMCP", "MCP server for building, running, debugging Xcode projects from AI agents. 5k+ stars on GitHub."),
            ("sosumi.ai", "Apple Developer docs translated to markdown for LLMs. MCP endpoint at sosumi.ai/mcp."),
            ("ShipSwift", "SwiftUI UI component library. MCP endpoint with production-ready patterns."),
            ("OpenAI macOS Plugin", "11 skills for macOS development: build-run-debug, swiftui-patterns, window-management, etc."),
            ("SwiftUI iOS Skills", "7 skills from user: storekit, swift-charts, swift-codable, swift-concurrency, swift-language, swift-testing, swiftdata."),
        ]

        for (title, body) in sources {
            let source = MindNode(
                type: .source,
                title: title,
                body: body,
                relevance: 0.6,
                confidence: 0.95,
                sourceOrigin: "auto_seed"
            )
            try? store.insertNode(source)
            try? store.insertLink(MindLink(sourceID: mpProject.id, targetID: source.id, linkType: .fromSource))
        }

        // 9. Add notes about architecture decisions
        let notes: [(String, String)] = [
            ("Architecture: SQLite + SwiftUI", "Single SQLite database with WAL mode. Nodes + Links tables. SwiftUI NavigationSplitView for sidebar/detail. No web views, no CRDT, no sync."),
            ("Data Model: One thing exists once", "All data is nodes + links. Views are queries, not copies. A note/task/person can appear in multiple places through links without duplication."),
            ("Scoring: Relevance + Confidence", "Two independent 0-1 scores. Relevance = what shows on Today/Desktop. Confidence = how certain is this data. Decays over time, boosted by access."),
            ("Build Philosophy", "Build-fix loop: swift build, see errors, fix, repeat. No Xcode needed for building. App bundle created by script/build_and_run.sh."),
        ]

        for (title, body) in notes {
            let note = MindNode(
                type: .note,
                title: title,
                body: body,
                relevance: 0.5,
                confidence: 0.9,
                sourceOrigin: "auto_seed"
            )
            try? store.insertNode(note)
            try? store.insertLink(MindLink(sourceID: mpProject.id, targetID: note.id, linkType: .belongsTo))
        }

        print("🧠 Seeded \(store.nodes.count) nodes, \(store.links.count) links")
    }

    // MARK: - File Scanning

    private static func seedFromFiles(store: NodeStore, projectID: UUID) async {
        // Use FileIngestor for proper scanning
        let result = FileIngestor.scan(maxDepth: 2, maxFiles: 80)
        FileIngestor.importToStore(result, store: store)
        
        // Link imported file sources to the project
        for node in store.nodes.values where node.sourceOrigin == "file_scan" {
            if !store.linkExists(sourceID: projectID, targetID: node.id, type: .fromSource) {
                try? store.insertLink(MindLink(sourceID: projectID, targetID: node.id, linkType: .fromSource))
            }
        }
    }

    // MARK: - Git Repos

    private static func seedFromGitRepos(store: NodeStore, projectID: UUID) async {
        let repos = [
            ("~/SecondBrain", "MindPalantir — the second brain app"),
            ("~/.hermes/hermes-agent", "Hermes Agent — AI orchestrator"),
        ]

        for (path, description) in repos {
            let expanded = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded + "/.git") {
                let note = MindNode(
                    type: .source,
                    title: "Git: \((path as NSString).lastPathComponent)",
                    body: description,
                    relevance: 0.6,
                    confidence: 0.9,
                    sourceOrigin: "git_scan"
                )
                try? store.insertNode(note)
                try? store.insertLink(MindLink(sourceID: projectID, targetID: note.id, linkType: .fromSource))
            }
        }
    }

    // MARK: - Homebrew

    private static func seedFromHomebrew(store: NodeStore) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let packages = output.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                let devPackages = packages.filter { pkg in
                    ["xcodebuildmcp", "imsg", "peekaboo", "cliclick", "fzf", "gh"].contains(pkg)
                }

                if !devPackages.isEmpty {
                    let note = MindNode(
                        type: .note,
                        title: "Dev Tools Installed",
                        body: "Homebrew: \(devPackages.joined(separator: ", "))",
                        relevance: 0.4,
                        confidence: 0.95,
                        sourceOrigin: "brew_scan"
                    )
                    try? store.insertNode(note)
                }
            }
        } catch {
            print("Failed to scan homebrew: \(error)")
        }
    }

    // MARK: - Helpers

    private static func sourceType(for ext: String) -> NodeType {
        switch ext {
        case "swift", "py", "js", "ts", "rs", "go", "rb": return .source
        case "md", "txt", "rtf": return .note
        case "png", "jpg", "jpeg", "gif", "pdf": return .source
        default: return .source
        }
    }

    private static func relevanceForRecentDate(_ date: Date) -> Double {
        let daysAgo = Date.now.timeIntervalSince(date) / 86400
        switch daysAgo {
        case ..<1: return 0.8
        case ..<7: return 0.6
        case ..<30: return 0.4
        default: return 0.2
        }
    }
}
