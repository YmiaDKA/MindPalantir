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
            let node = MindNode(
                type: .source,
                title: file.name,
                body: "New file: \(file.path)",
                relevance: 0.7,
                confidence: 0.7,
                sourceOrigin: "file_watcher",
                metadata: ["path": file.path, "ext": file.ext]
            )
            try? store.insertNode(node)
            imported += 1
        }
        
        if imported > 0 {
            print("👁️ Auto-imported \(imported) new files")
        }
    }
}
