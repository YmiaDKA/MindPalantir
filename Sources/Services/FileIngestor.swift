import Foundation

/// Scans local directories and creates nodes for interesting files.
/// Runs once on first launch, then can be re-triggered.
struct FileIngestor {
    
    // Directories to scan
    static let scanPaths: [(String, String)] = [
        ("~/Documents", "documents"),
        ("~/Desktop", "desktop"),
        ("~/Downloads", "downloads"),
        ("~/Projects", "projects"),
        ("~/Developer", "developer"),
    ]
    
    // File extensions we care about
    static let interestingExtensions: Set<String> = [
        "swift", "py", "js", "ts", "rs", "go", "rb", "java",
        "md", "txt", "org", "tex",
        "pdf", "doc", "docx",
        "png", "jpg", "jpeg", "gif", "webp", "svg",
        "json", "yaml", "yml", "toml",
        "sh", "zsh", "fish",
        "html", "css",
        "csv", "tsv",
        "mov", "mp4", "mp3", "wav",
    ]
    
    // Files/dirs to skip
    static let skipPatterns: Set<String> = [
        "node_modules", ".git", ".build", "Pods", "Carthage",
        "DerivedData", ".DS_Store", "venv", "__pycache__",
        ".next", "dist", "build", "target", ".cache",
    ]
    
    struct ScanResult {
        let files: [FileInfo]
        let directories: [DirInfo]
        let gitRepos: [String]
    }
    
    struct FileInfo {
        let path: String
        let name: String
        let ext: String
        let size: Int64
        let modified: Date
        let category: String
    }
    
    struct DirInfo {
        let path: String
        let name: String
        let fileCount: Int
        let category: String
    }
    
    // MARK: - Scan
    
    /// Scan all configured directories (max 2 levels deep).
    static func scan(maxDepth: Int = 2, maxFiles: Int = 200) -> ScanResult {
        var files: [FileInfo] = []
        var directories: [DirInfo] = []
        var gitRepos: [String] = []
        var scanned = 0
        
        for (rawPath, category) in scanPaths {
            let expanded = NSString(string: rawPath).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }
            
            scanDirectory(
                path: expanded,
                depth: 0,
                maxDepth: maxDepth,
                category: category,
                files: &files,
                directories: &directories,
                gitRepos: &gitRepos,
                scanned: &scanned,
                maxFiles: maxFiles
            )
            
            if scanned >= maxFiles { break }
        }
        
        return ScanResult(files: files, directories: directories, gitRepos: gitRepos)
    }
    
    private static func scanDirectory(
        path: String,
        depth: Int,
        maxDepth: Int,
        category: String,
        files: inout [FileInfo],
        directories: inout [DirInfo],
        gitRepos: inout [String],
        scanned: inout Int,
        maxFiles: Int
    ) {
        guard depth <= maxDepth, scanned < maxFiles else { return }
        
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return }
        
        var dirFileCount = 0
        let dirName = (path as NSString).lastPathComponent
        
        for item in contents {
            guard scanned < maxFiles else { break }
            guard !skipPatterns.contains(item) else { continue }
            
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
            
            if isDir.boolValue {
                // Check for git repos
                if item == ".git" {
                    gitRepos.append(dirName)
                    continue
                }
                
                // Recurse
                scanDirectory(
                    path: fullPath,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    category: category,
                    files: &files,
                    directories: &directories,
                    gitRepos: &gitRepos,
                    scanned: &scanned,
                    maxFiles: maxFiles
                )
                
                directories.append(DirInfo(
                    path: fullPath,
                    name: item,
                    fileCount: 0,
                    category: category
                ))
            } else {
                let ext = (item as NSString).pathExtension.lowercased()
                guard interestingExtensions.contains(ext) else { continue }
                
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let size = attrs[.size] as? Int64,
                      let modified = attrs[.modificationDate] as? Date
                else { continue }
                
                files.append(FileInfo(
                    path: fullPath,
                    name: item,
                    ext: ext,
                    size: size,
                    modified: modified,
                    category: category
                ))
                dirFileCount += 1
                scanned += 1
            }
        }
    }
    
    // MARK: - Convert to Nodes
    
    /// Import scan results into the store as Source nodes.
    @MainActor
    static func importToStore(_ result: ScanResult, store: NodeStore) {
        var imported = 0
        
        // Import interesting files as Source nodes
        for file in result.files.prefix(50) {
            let node = MindNode(
                type: .source,
                title: file.name,
                body: "\(file.category): \(file.path)\n\(formatSize(file.size)) · modified \(file.modified.formatted(date: .abbreviated, time: .shortened))",
                relevance: relevanceForFile(file),
                confidence: 0.9,
                status: .active,
                sourceOrigin: "file_scan",
                metadata: [
                    "path": file.path,
                    "ext": file.ext,
                    "size": "\(file.size)",
                    "category": file.category,
                ]
            )
            try? store.insertNode(node)
            imported += 1
        }
        
        // Import git repos as Source nodes
        for repo in Set(result.gitRepos) {
            let node = MindNode(
                type: .source,
                title: "\(repo) (git)",
                body: "Git repository",
                relevance: 0.6,
                confidence: 0.95,
                status: .active,
                sourceOrigin: "git_scan",
                metadata: ["type": "git_repo", "name": repo]
            )
            try? store.insertNode(node)
            imported += 1
        }
        
        print("📥 Imported \(imported) items from file scan")
    }
    
    private static func relevanceForFile(_ file: FileInfo) -> Double {
        // More recently modified = more relevant
        let daysSinceModified = Date().timeIntervalSince(file.modified) / 86400
        let recencyScore = max(0, 1.0 - (daysSinceModified / 30))
        
        // Code files slightly more relevant
        let typeBonus: Double = ["swift", "py", "js", "ts", "md"].contains(file.ext) ? 0.1 : 0
        
        return min(1.0, 0.3 + recencyScore * 0.5 + typeBonus)
    }
    
    private static func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }
}
