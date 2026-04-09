import Foundation

/// Imports Safari bookmarks, reading list, and visit history as nodes.
struct SafariImporter {
    
    // MARK: - Bookmarks
    
    /// Parse Safari Bookmarks.plist and create Source nodes.
    @MainActor
    static func importBookmarks(store: NodeStore) {
        let plistPath = NSString(string: "~/Library/Safari/Bookmarks.plist").expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            print("📚 Could not read Safari Bookmarks.plist")
            return
        }
        
        var imported = 0
        var seenURLs = Set<String>()
        
        // Recursively extract bookmarks
        func extract(_ item: [String: Any], folder: String = "") {
            // If it has a URL, it's a bookmark
            if let urlString = item["URLString"] as? String,
               let title = item["Title"] as? String,
               !urlString.isEmpty, !seenURLs.contains(urlString) {
                seenURLs.insert(urlString)
                
                // Skip common/useless bookmarks
                let skipDomains = ["apple.com/icloud", "apple.com/news"]
                if skipDomains.contains(where: { urlString.contains($0) }) { return }
                
                let category = categorizeURL(urlString)
                let node = MindNode(
                    type: .source,
                    title: title.isEmpty ? urlString : title,
                    body: urlString,
                    relevance: relevanceForBookmark(category: category),
                    confidence: 0.85,
                    status: .active,
                    sourceOrigin: "safari_bookmark",
                    metadata: [
                        "url": urlString,
                        "folder": folder,
                        "category": category,
                        "source": "safari"
                    ]
                )
                try? store.insertNode(node)
                imported += 1
            }
            
            // Recurse into children (folders)
            if let children = item["Children"] as? [[String: Any]] {
                let folderName = item["Title"] as? String ?? folder
                for child in children {
                    extract(child, folder: folderName)
                }
            }
        }
        
        // Start from the root
        if let children = plist["Children"] as? [[String: Any]] {
            for child in children {
                extract(child)
            }
        }
        
        print("📚 Imported \(imported) Safari bookmarks")
    }
    
    // MARK: - History
    
    /// Import top visited sites from Safari history.
    @MainActor
    static func importHistory(store: NodeStore, limit: Int = 30) {
        let historyPath = NSString(string: "~/Library/Safari/History.db").expandingTildeInPath
        guard FileManager.default.fileExists(atPath: historyPath) else {
            print("📚 No Safari history database found")
            return
        }
        
        // Use sqlite3 command to query (avoid locking the DB)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            historyPath,
            """
            SELECT h.url, 
                   CASE WHEN hv.title != '' THEN hv.title ELSE h.url END as title,
                   COUNT(*) as visit_count,
                   MAX(hv.visit_time) as last_visit
            FROM history_items h
            JOIN history_visits hv ON h.id = hv.history_item
            WHERE h.url NOT LIKE '%google.com/search%'
              AND h.url NOT LIKE '%localhost%'
              AND h.url NOT LIKE '%apple.com%'
            GROUP BY h.url
            ORDER BY visit_count DESC
            LIMIT \(limit);
            """
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                var imported = 0
                
                for line in lines {
                    let parts = line.components(separatedBy: "|")
                    guard parts.count >= 4 else { continue }
                    
                    let url = parts[0]
                    let title = parts[1]
                    let visitCount = Int(parts[2]) ?? 1
                    let category = categorizeURL(url)
                    
                    let node = MindNode(
                        type: .source,
                        title: title.isEmpty ? url : title,
                        body: "\(url)\nVisited \(visitCount) times",
                        relevance: min(0.9, Double(visitCount) / 20.0),
                        confidence: 0.8,
                        status: .active,
                        sourceOrigin: "safari_history",
                        metadata: [
                            "url": url,
                            "visits": "\(visitCount)",
                            "category": category,
                            "source": "safari"
                        ]
                    )
                    try? store.insertNode(node)
                    imported += 1
                }
                
                print("📚 Imported \(imported) Safari history entries")
            }
        } catch {
            print("📚 Failed to read Safari history: \(error)")
        }
    }
    
    // MARK: - Reading List
    
    @MainActor
    static func importReadingList(store: NodeStore) {
        let plistPath = NSString(string: "~/Library/Safari/Bookmarks.plist").expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return }
        
        // Reading list is in the Children array with title "ReadingList"
        var imported = 0
        
        func findReadingList(_ item: [String: Any]) {
            if item["Title"] as? String == "com.apple.ReadingList" {
                if let children = item["Children"] as? [[String: Any]] {
                    for child in children {
                        guard let url = child["URLString"] as? String,
                              let title = child["Title"] as? String,
                              !url.isEmpty else { continue }
                        
                        let node = MindNode(
                            type: .source,
                            title: title,
                            body: "Reading List: \(url)",
                            relevance: 0.6,
                            confidence: 0.9,
                            status: .active,
                            sourceOrigin: "safari_reading_list",
                            metadata: ["url": url, "source": "safari"]
                        )
                        try? store.insertNode(node)
                        imported += 1
                    }
                }
                return
            }
            
            if let children = item["Children"] as? [[String: Any]] {
                for child in children {
                    findReadingList(child)
                }
            }
        }
        
        if let children = plist["Children"] as? [[String: Any]] {
            for child in children {
                findReadingList(child)
            }
        }
        
        if imported > 0 {
            print("📚 Imported \(imported) Safari Reading List items")
        }
    }
    
    // MARK: - Helpers
    
    private static func categorizeURL(_ url: String) -> String {
        let lower = url.lowercased()
        if lower.contains("github.com") || lower.contains("gitlab") { return "code" }
        if lower.contains("youtube.com") || lower.contains("cobalt") { return "media" }
        if lower.contains("twitter.com") || lower.contains("x.com") || lower.contains("reddit") { return "social" }
        if lower.contains("drive.google") || lower.contains("docs.google") { return "document" }
        if lower.contains("figma.com") || lower.contains("spline") || lower.contains("jitter") { return "design" }
        if lower.contains("instructure") || lower.contains("oslomet") || lower.contains("edu") { return "school" }
        if lower.contains("mail.google") || lower.contains("gmail") { return "email" }
        return "web"
    }
    
    private static func relevanceForBookmark(category: String) -> Double {
        switch category {
        case "code": 0.7
        case "design": 0.6
        case "school": 0.65
        case "document": 0.5
        case "social": 0.3
        case "media": 0.3
        case "email": 0.4
        default: 0.4
        }
    }
}
