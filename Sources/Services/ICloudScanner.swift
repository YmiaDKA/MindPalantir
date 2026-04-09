import Foundation

/// Scans iCloud Drive for projects and files.
/// Creates Project nodes for design/dev folders, Source nodes for files.
struct ICloudScanner {
    
    static let iCloudPath = NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs").expandingTildeInPath
    
    // Project indicators — folders that look like active projects
    static let projectIndicators = ["Plakater", "RYDDE", "OTHER PROJECTS", "TIE", "WASIM", "Rema", "Faktura", "Essayist"]
    
    // File types we care about
    static let interestingExtensions: Set<String> = [
        "psd", "ai", "sketch", "fig", "pdf", "numbers", "pages", "key",
        "png", "jpg", "jpeg", "gif", "webp", "svg",
        "mp3", "wav", "m4a", "mp4", "mov",
        "zip", "rar",
        "swift", "py", "js", "html", "css",
        "md", "txt", "org",
    ]
    
    struct ScanResult {
        let files: [FileInfo]
        let projects: [ProjectInfo]
        let totalSize: Int64
    }
    
    struct FileInfo {
        let name: String
        let path: String
        let ext: String
        let size: Int64
        let modified: Date
        let parentFolder: String
    }
    
    struct ProjectInfo {
        let name: String
        let path: String
        let fileCount: Int
        let totalSize: Int64
        let lastModified: Date
    }
    
    // MARK: - Scan
    
    static func scan(maxDepth: Int = 3, maxFiles: Int = 100) -> ScanResult {
        var files: [FileInfo] = []
        var projects: [ProjectInfo] = []
        var totalSize: Int64 = 0
        var scanned = 0
        
        scanDirectory(
            path: iCloudPath,
            depth: 0,
            maxDepth: maxDepth,
            parentFolder: "iCloud",
            files: &files,
            projects: &projects,
            totalSize: &totalSize,
            scanned: &scanned,
            maxFiles: maxFiles
        )
        
        return ScanResult(files: files, projects: projects, totalSize: totalSize)
    }
    
    private static func scanDirectory(
        path: String,
        depth: Int,
        maxDepth: Int,
        parentFolder: String,
        files: inout [FileInfo],
        projects: inout [ProjectInfo],
        totalSize: inout Int64,
        scanned: inout Int,
        maxFiles: Int
    ) {
        guard depth <= maxDepth, scanned < maxFiles else { return }
        
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return }
        
        let dirName = (path as NSString).lastPathComponent
        var dirFiles: [FileInfo] = []
        var dirSize: Int64 = 0
        
        for item in contents {
            guard scanned < maxFiles else { break }
            guard !item.hasPrefix(".") else { continue }
            
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
            
            if isDir.boolValue {
                // Check if this looks like a project
                let isProject = projectIndicators.contains(where: { item.localizedCaseInsensitiveContains($0) })
                
                if isProject && depth < 2 {
                    // Scan the project folder
                    var projFiles: [FileInfo] = []
                    var projSize: Int64 = 0
                    var projScanned = 0
                    scanDirectory(
                        path: fullPath, depth: depth + 1, maxDepth: depth + 2,
                        parentFolder: item, files: &projFiles, projects: &projects,
                        totalSize: &projSize, scanned: &projScanned, maxFiles: 30
                    )
                    let lastMod = projFiles.map(\.modified).max() ?? .now
                    projects.append(ProjectInfo(
                        name: item, path: fullPath,
                        fileCount: projFiles.count, totalSize: projSize,
                        lastModified: lastMod
                    ))
                    files.append(contentsOf: projFiles)
                    scanned += projFiles.count
                } else {
                    scanDirectory(
                        path: fullPath, depth: depth + 1, maxDepth: maxDepth,
                        parentFolder: item, files: &files, projects: &projects,
                        totalSize: &totalSize, scanned: &scanned, maxFiles: maxFiles
                    )
                }
            } else {
                let ext = (item as NSString).pathExtension.lowercased()
                guard interestingExtensions.contains(ext) else { continue }
                
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let size = attrs[.size] as? Int64,
                      let modified = attrs[.modificationDate] as? Date
                else { continue }
                
                let info = FileInfo(
                    name: item, path: fullPath, ext: ext,
                    size: size, modified: modified, parentFolder: parentFolder
                )
                dirFiles.append(info)
                dirSize += size
                totalSize += size
                scanned += 1
            }
        }
        
        files.append(contentsOf: dirFiles)
    }
    
    // MARK: - Import to Store
    
    @MainActor
    static func importToStore(_ result: ScanResult, store: NodeStore) {
        var imported = 0
        
        // Import projects
        for proj in result.projects {
            let daysSinceModified = Date.now.timeIntervalSince(proj.lastModified) / 86400
            
            let node = MindNode(
                type: .project,
                title: proj.name,
                body: "iCloud project — \(proj.fileCount) files, \(formatSize(proj.totalSize))",
                relevance: daysSinceModified < 7 ? 0.7 : (daysSinceModified < 30 ? 0.5 : 0.3),
                confidence: 0.85,
                status: daysSinceModified < 30 ? .active : .archived,
                sourceOrigin: "icloud_scan",
                metadata: ["path": proj.path, "source": "icloud"]
            )
            try? store.insertNode(node)
            imported += 1
        }
        
        // Import individual files (top-level only, not nested in projects)
        let topLevelFiles = result.files.filter { file in
            !result.projects.contains(where: { file.path.hasPrefix($0.path) })
        }
        
        for file in topLevelFiles.prefix(30) {
            let node = MindNode(
                type: .source,
                title: file.name,
                body: "\(file.parentFolder): \(file.path)\n\(formatSize(file.size))",
                relevance: file.size > 10_000_000 ? 0.5 : 0.3, // Large files more relevant
                confidence: 0.9,
                status: .active,
                sourceOrigin: "icloud_scan",
                metadata: [
                    "path": file.path,
                    "ext": file.ext,
                    "size": "\(file.size)",
                    "source": "icloud"
                ]
            )
            try? store.insertNode(node)
            imported += 1
        }
        
        print("☁️ Imported \(imported) iCloud items (\(result.projects.count) projects, \(topLevelFiles.count) files)")
    }
    
    private static func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}
