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
        
        // 3b. Import Safari bookmarks + history
        SafariImporter.importBookmarks(store: store)
        SafariImporter.importReadingList(store: store)
        SafariImporter.importHistory(store: store, limit: 25)
        
        // 3c. Import iCloud Drive
        let iCloudResult = ICloudScanner.scan(maxDepth: 2, maxFiles: 60)
        ICloudScanner.importToStore(iCloudResult, store: store)

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

        // 7. School project
        let schoolProject = MindNode(
            type: .project,
            title: "OsloMet — Design & Dev",
            body: "Bachelor studies at OsloMet. Course BAPD2100. Design, development, and digital communication.",
            relevance: 0.75,
            confidence: 0.8,
            status: .active,
            sourceOrigin: "auto_seed"
        )
        try? store.insertNode(schoolProject)
        try? store.insertLink(MindLink(sourceID: schoolProject.id, targetID: mpProject.id, linkType: .relatedTo))
        
        // 8. Design projects from iCloud
        let designProjects: [(String, String)] = [
            ("RYDDE — Poster Design", "Design posters for chips, eddik & saus products. Part of RYDDE 2 project."),
            ("TIE — Clothing Brand", "Opium logo and tie designs for a clothing brand."),
            ("WASIM — Logo Design", "Logo design project."),
            ("Rema 1000 — Shopping Bag", "Nett/bag design for Rema 1000."),
        ]
        for (title, body) in designProjects {
            let node = MindNode(
                type: .project,
                title: title,
                body: body,
                relevance: 0.6,
                confidence: 0.7,
                status: .active,
                sourceOrigin: "icloud_projects"
            )
            try? store.insertNode(node)
            try? store.insertLink(MindLink(sourceID: devProject.id, targetID: node.id, linkType: .relatedTo))
        }
        
        // 9. Create people from conversation context
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

        // 9. Auto-link related nodes
        autoLinkNodes(store: store)
        
        // 10. Add notes about architecture decisions
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

    // MARK: - Auto-Linking
    
    /// Automatically create links between related nodes based on content similarity.
    private static func autoLinkNodes(store: NodeStore) {
        var linked = 0
        let allNodes = Array(store.nodes.values)
        NSLog("🔍 autoLinkNodes: \(allNodes.count) nodes, \(store.links.count) existing links")
        
        // 1. Link file_scan sources to MindPalantir project
        if let mp = allNodes.first(where: { $0.title == "MindPalantir" && $0.type == .project }) {
            let fileSources = allNodes.filter { $0.sourceOrigin == "file_scan" && $0.type == .source }
            NSLog("🔍 Found \(fileSources.count) file_scan sources")
            for source in fileSources.prefix(20) {
                let exists = store.linkExists(sourceID: mp.id, targetID: source.id, type: .fromSource)
                if !exists {
                    do {
                        try store.insertLink(MindLink(sourceID: mp.id, targetID: source.id, linkType: .fromSource, weight: 0.3))
                        linked += 1
                    } catch {
                        NSLog("❌ insertLink error: \(error)")
                    }
                }
            }
        }
        
        // 2. Link git scan sources to MindPalantir
        if let mp = allNodes.first(where: { $0.title == "MindPalantir" && $0.type == .project }) {
            let gitSources = allNodes.filter { $0.sourceOrigin == "git_scan" }
            for source in gitSources {
                if !store.linkExists(sourceID: mp.id, targetID: source.id, type: .fromSource) {
                    try? store.insertLink(MindLink(sourceID: mp.id, targetID: source.id, linkType: .fromSource, weight: 0.5))
                    linked += 1
                }
            }
        }
        
        // 3. Link Safari history entries to related projects by URL content
        let historyNodes = allNodes.filter { $0.sourceOrigin == "safari_history" }
        let projects = allNodes.filter { $0.type == .project }
        
        for history in historyNodes {
            let url = history.metadata["url"] ?? ""
            let category = history.metadata["category"] ?? ""
            
            // Match by category
            for project in projects {
                var shouldLink = false
                var weight: Double = 0.2
                
                if category == "code" && project.title == "MindPalantir" {
                    shouldLink = true; weight = 0.4
                } else if category == "school" && project.title.contains("OsloMet") {
                    shouldLink = true; weight = 0.4
                } else if category == "design" && (project.title.contains("RYDDE") || project.title.contains("TIE") || project.title.contains("WASIM")) {
                    shouldLink = true; weight = 0.3
                }
                
                if shouldLink && !store.linkExists(sourceID: project.id, targetID: history.id, type: .fromSource) {
                    try? store.insertLink(MindLink(sourceID: project.id, targetID: history.id, linkType: .fromSource, weight: weight))
                    linked += 1
                }
            }
        }
        
        // 4. Link iCloud scan files to their parent project
        let icloudFiles = allNodes.filter { $0.sourceOrigin == "icloud_scan" && $0.type == .source }
        let icloudProjects = allNodes.filter { $0.sourceOrigin == "icloud_projects" || ($0.sourceOrigin == "icloud_scan" && $0.type == .project) }
        
        for file in icloudFiles {
            let filePath = file.metadata["path"] ?? ""
            for project in icloudProjects {
                if filePath.contains(project.title) || filePath.hasPrefix(project.metadata["path"] ?? "") {
                    if !store.linkExists(sourceID: project.id, targetID: file.id, type: .fromSource) {
                        try? store.insertLink(MindLink(sourceID: project.id, targetID: file.id, linkType: .fromSource, weight: 0.3))
                        linked += 1
                    }
                    break
                }
            }
        }
        
        // 5. Link all projects to Ibrahim as mentions
        if let ibrahim = allNodes.first(where: { $0.title == "Ibrahim" && $0.type == .person }) {
            for project in projects {
                if !store.linkExists(sourceID: project.id, targetID: ibrahim.id, type: .mentions) {
                    try? store.insertLink(MindLink(sourceID: project.id, targetID: ibrahim.id, linkType: .mentions, weight: 0.5))
                    linked += 1
                }
            }
        }
        
        // 6. Link related projects to each other
        let designProjects = projects.filter { $0.title.contains("RYDDE") || $0.title.contains("TIE") || $0.title.contains("WASIM") || $0.title.contains("Rema") }
        for i in 0..<designProjects.count {
            for j in (i+1)..<designProjects.count {
                if !store.linkExists(sourceID: designProjects[i].id, targetID: designProjects[j].id, type: .relatedTo) {
                    try? store.insertLink(MindLink(sourceID: designProjects[i].id, targetID: designProjects[j].id, linkType: .relatedTo, weight: 0.2))
                    linked += 1
                }
            }
        }
        
        if linked > 0 {
            NSLog("🔗 Auto-linked \(linked) related nodes")
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
