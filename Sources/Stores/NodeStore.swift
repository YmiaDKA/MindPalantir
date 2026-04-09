import Foundation
import SQLite3

/// The single persistent store. One thing exists once.
/// Views are queries on this store, not copies.
/// 
/// WAL mode + explicit checkpointing ensures data survives restarts.
@Observable
@MainActor
final class NodeStore {
    private var db: OpaquePointer?
    let dbPath: String

    // In-memory cache — loaded from SQLite on open
    private(set) var nodes: [UUID: MindNode] = [:]
    private(set) var links: [UUID: MindLink] = [:]

    // Change counter for SwiftUI observation
    var changeCount: Int = 0

    init(path: String? = nil) {
        if let path {
            dbPath = path
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MindPalantir", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            dbPath = dir.appendingPathComponent("brain.db").path
        }
    }

    // MARK: - Lifecycle

    func open() throws {
        NSLog("📂 Opening DB at: \(dbPath)")
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { throw StoreError.openFailed }
        
        // WAL + safe checkpointing — critical for data survival across restarts
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=NORMAL")       // balance: safe + fast
        try exec("PRAGMA wal_autocheckpoint=100")    // auto-checkpoint every 100 pages
        try exec("PRAGMA busy_timeout=5000")         // wait if locked, don't fail
        // NOTE: foreign_keys OFF — the UNIQUE constraint on dedupe_key + FK causes silent insert failures in WAL mode
        // Deduplication handled in code via linkExists()
        // try exec("PRAGMA foreign_keys=ON")
        
        try createTables()
        try migrateSchema()
        try loadAll()
        
        // Force checkpoint on open to consolidate any leftover WAL
        sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_PASSIVE, nil, nil)
    }

    func close() {
        // Force checkpoint before closing — ensures all WAL data hits main DB
        if let db {
            sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_FULL, nil, nil)
            sqlite3_close(db)
        }
        db = nil
    }
    
    /// Force WAL checkpoint — call after large batch inserts (seeding, import)
    func checkpoint() {
        if let db {
            sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_PASSIVE, nil, nil)
        }
    }

    // MARK: - Schema

    private func createTables() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS nodes (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT DEFAULT '',
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            last_accessed_at REAL NOT NULL,
            relevance REAL DEFAULT 0.5,
            confidence REAL DEFAULT 0.8,
            status TEXT DEFAULT 'active',
            pinned INTEGER DEFAULT 0,
            source_origin TEXT,
            metadata TEXT DEFAULT '{}',
            due_date REAL,
            access_count INTEGER DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_nodes_type ON nodes(type);
        CREATE INDEX IF NOT EXISTS idx_nodes_relevance ON nodes(relevance DESC);
        CREATE INDEX IF NOT EXISTS idx_nodes_updated ON nodes(updated_at DESC);
        CREATE INDEX IF NOT EXISTS idx_nodes_status ON nodes(status);
        CREATE INDEX IF NOT EXISTS idx_nodes_pinned ON nodes(pinned);
        """)

        try exec("""
        CREATE TABLE IF NOT EXISTS links (
            id TEXT PRIMARY KEY,
            source_id TEXT NOT NULL,
            target_id TEXT NOT NULL,
            link_type TEXT NOT NULL DEFAULT 'relatedTo',
            weight REAL DEFAULT 0.5,
            created_at REAL NOT NULL,
            dedupe_key TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_links_source ON links(source_id);
        CREATE INDEX IF NOT EXISTS idx_links_target ON links(target_id);
        CREATE INDEX IF NOT EXISTS idx_links_dedupe ON links(dedupe_key);
        """)

        // FTS5 full-text search — standalone table, maintained manually
        try exec("""
        CREATE VIRTUAL TABLE IF NOT EXISTS nodes_fts USING fts5(
            node_id UNINDEXED,
            title,
            body,
            tokenize='porter unicode61'
        );
        """)
    }

    // MARK: - Migration

    private func migrateSchema() throws {
        // Check if column exists before attempting migration
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(nodes)", -1, &stmt, nil) == SQLITE_OK {
            var hasAccessCount = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let name = sqlite3_column_text(stmt, 1) {
                    if String(cString: name) == "access_count" {
                        hasAccessCount = true
                        break
                    }
                }
            }
            sqlite3_finalize(stmt)
            if !hasAccessCount {
                try exec("ALTER TABLE nodes ADD COLUMN access_count INTEGER DEFAULT 0")
            }
        }
    }

    // MARK: - Node CRUD

    func insertNode(_ node: MindNode) throws {
        let sql = """
        INSERT OR REPLACE INTO nodes
        (id, type, title, body, created_at, updated_at, last_accessed_at,
         relevance, confidence, status, pinned, source_origin, metadata, due_date, access_count)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw StoreError.queryFailed }
        defer { sqlite3_finalize(stmt) }

        let metaJSON = String(data: (try? JSONEncoder().encode(node.metadata)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}"

        let idStr = node.id.uuidString as NSString
        let typeStr = node.type.rawValue as NSString
        let titleStr = node.title as NSString
        let bodyStr = node.body as NSString
        let statusStr = node.status.rawValue as NSString
        let originStr = (node.sourceOrigin ?? "") as NSString
        let metaStr = metaJSON as NSString

        sqlite3_bind_text(stmt, 1, idStr.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, typeStr.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, titleStr.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, bodyStr.utf8String, -1, nil)
        sqlite3_bind_double(stmt, 5, node.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 6, node.updatedAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 7, node.lastAccessedAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 8, node.relevance)
        sqlite3_bind_double(stmt, 9, node.confidence)
        sqlite3_bind_text(stmt, 10, statusStr.utf8String, -1, nil)
        sqlite3_bind_int(stmt, 11, node.pinned ? 1 : 0)
        sqlite3_bind_text(stmt, 12, originStr.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 13, metaStr.utf8String, -1, nil)
        if let due = node.dueDate {
            sqlite3_bind_double(stmt, 14, due.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 14)
        }
        sqlite3_bind_int(stmt, 15, Int32(node.accessCount))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let errMsg = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
            NSLog("❌ insertNode failed: \(errMsg)")
            throw StoreError.queryFailed
        }

        // Update FTS5 index
        try? exec("DELETE FROM nodes_fts WHERE node_id = '\(node.id.uuidString)'")
        let ftsSQL = "INSERT INTO nodes_fts (node_id, title, body) VALUES (?, ?, ?)"
        var ftsStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, ftsSQL, -1, &ftsStmt, nil) == SQLITE_OK {
            let idCStr = node.id.uuidString.cString(using: .utf8)
            let titleCStr = node.title.cString(using: .utf8)
            let bodyCStr = node.body.cString(using: .utf8)
            sqlite3_bind_text(ftsStmt, 1, idCStr, -1, nil)
            sqlite3_bind_text(ftsStmt, 2, titleCStr, -1, nil)
            sqlite3_bind_text(ftsStmt, 3, bodyCStr, -1, nil)
            sqlite3_step(ftsStmt)
        }
        sqlite3_finalize(ftsStmt)

        nodes[node.id] = node
        changeCount += 1

        // Auto-link: if new node mentions existing nodes, create relatedTo links
        autoLinkMentions(node)
    }

    /// Check if a new node mentions existing nodes by name and auto-create links.
    /// Bridges the gap between "manually linked" and "Hermes classified."
    private func autoLinkMentions(_ node: MindNode) {
        let text = (node.title + " " + node.body).lowercased()
        guard text.count > 10 else { return } // skip very short nodes

        for (_, existing) in nodes {
            guard existing.id != node.id else { continue }
            // Only check nodes with meaningful titles (>3 chars)
            let name = existing.title.lowercased()
            guard name.count > 3 else { continue }

            if text.contains(name) {
                // Don't link to self, don't double-link
                if !linkExists(sourceID: node.id, targetID: existing.id, type: .relatedTo) {
                    let link = MindLink(sourceID: node.id, targetID: existing.id, linkType: .relatedTo)
                    try? insertLink(link)
                }
            }
        }
    }

    func deleteNode(id: UUID) throws {
        let idStr = id.uuidString
        try exec("DELETE FROM links WHERE source_id='\(idStr)' OR target_id='\(idStr)'")
        try exec("DELETE FROM nodes WHERE id='\(idStr)'")
        try? exec("DELETE FROM nodes_fts WHERE node_id='\(idStr)'")
        nodes.removeValue(forKey: id)
        links = links.filter { $0.value.sourceID != id && $0.value.targetID != id }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
        changeCount += 1
    }

    // MARK: - Link CRUD — uses prepared statements like insertNode for reliability

    func insertLink(_ link: MindLink) throws {
        let sql = """
        INSERT OR IGNORE INTO links (id, source_id, target_id, link_type, weight, created_at, dedupe_key)
        VALUES (?,?,?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
            NSLog("❌ insertLink prepare failed: \(errMsg)")
            throw StoreError.queryFailed
        }
        defer { sqlite3_finalize(stmt) }

        let idStr = link.id.uuidString as NSString
        let srcStr = link.sourceID.uuidString as NSString
        let tgtStr = link.targetID.uuidString as NSString
        let typeStr = link.linkType.rawValue as NSString
        let dedupeStr = link.dedupeKey as NSString

        sqlite3_bind_text(stmt, 1, idStr.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, srcStr.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, tgtStr.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, typeStr.utf8String, -1, nil)
        sqlite3_bind_double(stmt, 5, link.weight)
        sqlite3_bind_double(stmt, 6, link.createdAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 7, dedupeStr.utf8String, -1, nil)

        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE {
            let errMsg = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
            NSLog("❌ insertLink failed: \(errMsg)")
            throw StoreError.queryFailed
        }
        links[link.id] = link
        changeCount += 1
    }

    func deleteLink(id: UUID) throws {
        let sql = "DELETE FROM links WHERE id=?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw StoreError.queryFailed }
        defer { sqlite3_finalize(stmt) }
        let idStr = id.uuidString as NSString
        sqlite3_bind_text(stmt, 1, idStr.utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw StoreError.queryFailed }
        links.removeValue(forKey: id)
        changeCount += 1
    }

    // MARK: - Queries (views on the same data)

    func nodes(ofType type: NodeType) -> [MindNode] {
        nodes.values.filter { $0.type == type }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func activeNodes(ofType type: NodeType) -> [MindNode] {
        nodes.values.filter { $0.type == type && $0.status == .active }
            .sorted { $0.relevance > $1.relevance }
    }

    /// Today/Desktop: pinned + high relevance active items
    func todayNodes(limit: Int = 20) -> [MindNode] {
        nodes.values
            .filter { $0.pinned || ($0.status == .active && $0.relevance > 0.3) }
            .sorted { a, b in
                if a.pinned != b.pinned { return a.pinned }
                return a.relevance > b.relevance
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Recent nodes (timeline)
    func recentNodes(days: Int = 7, limit: Int = 30) -> [MindNode] {
        let cutoff = Date.now.addingTimeInterval(-Double(days) * 86400)
        return nodes.values
            .filter { $0.updatedAt > cutoff }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    /// Nodes needing clarification (low confidence)
    func uncertainNodes(limit: Int = 20) -> [MindNode] {
        nodes.values
            .filter { $0.confidence < 0.6 }
            .sorted { $0.confidence < $1.confidence }
            .prefix(limit)
            .map { $0 }
    }

    /// All links for a node (both directions)
    func linksFor(nodeID: UUID) -> [MindLink] {
        links.values.filter { $0.sourceID == nodeID || $0.targetID == nodeID }
    }

    /// Connected nodes
    func connectedNodes(for nodeID: UUID) -> [MindNode] {
        let connectedIDs = Set(
            linksFor(nodeID: nodeID).map { $0.sourceID == nodeID ? $0.targetID : $0.sourceID }
        )
        return nodes.values.filter { connectedIDs.contains($0.id) }
    }

    /// Children via specific link type
    func children(of nodeID: UUID, linkType: LinkType) -> [MindNode] {
        let childIDs = Set(
            links.values
                .filter { $0.sourceID == nodeID && $0.linkType == linkType }
                .map { $0.targetID }
        )
        return nodes.values.filter { childIDs.contains($0.id) }
    }

    /// Check if a link already exists (deduplication)
    func linkExists(sourceID: UUID, targetID: UUID, type: LinkType) -> Bool {
        let key = "\(sourceID.uuidString)_\(targetID.uuidString)_\(type.rawValue)"
        return links.values.contains { $0.dedupeKey == key }
    }
    
    /// Strongest connection between two nodes (for graph view)
    func strongestLink(between a: UUID, and b: UUID) -> MindLink? {
        links.values
            .filter { ($0.sourceID == a && $0.targetID == b) || ($0.sourceID == b && $0.targetID == a) }
            .max { $0.weight < $1.weight }
    }

    /// Backlinks — nodes that link TO the given node (the wiki essential).
    /// Returns (node, linkType) pairs grouped by link type for the inspector.
    func backlinks(for nodeID: UUID) -> [(node: MindNode, linkType: LinkType)] {
        let incoming = links.values.filter { $0.targetID == nodeID }
        return incoming.compactMap { link in
            guard let source = nodes[link.sourceID] else { return nil }
            return (node: source, linkType: link.linkType)
        }
        .sorted { $0.node.updatedAt > $1.node.updatedAt }
    }

    // MARK: - Full-Text Search (FTS5)

    /// Search nodes using FTS5 with Porter stemming.
    /// Returns results ranked by relevance score.
    func search(_ query: String, limit: Int = 20) -> [MindNode] {
        guard !query.isEmpty else { return [] }

        // Escape single quotes for FTS5
        let escaped = query.replacingOccurrences(of: "'", with: "''")

        // Build FTS5 query: prefix match each term
        let terms = escaped.split(separator: " ").map { "\($0)*" }.joined(separator: " ")
        let sql = """
        SELECT node_id FROM nodes_fts
        WHERE nodes_fts MATCH '\(terms)'
        ORDER BY rank
        LIMIT \(limit)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            // FTS5 parse error — fall back to simple LIKE
            return nodes.values
                .filter {
                    $0.title.localizedCaseInsensitiveContains(query) ||
                    $0.body.localizedCaseInsensitiveContains(query)
                }
                .sorted { $0.relevance > $1.relevance }
                .prefix(limit)
                .map { $0 }
        }
        defer { sqlite3_finalize(stmt) }

        var ids: [UUID] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let text = sqlite3_column_text(stmt, 0),
               let uuid = UUID(uuidString: String(cString: text)) {
                ids.append(uuid)
            }
        }

        return ids.compactMap { nodes[$0] }
    }

    /// Rebuild FTS5 index from scratch — call on first run or if index seems stale
    func rebuildSearchIndex() {
        try? exec("DELETE FROM nodes_fts")
        let ftsSQL = "INSERT INTO nodes_fts (node_id, title, body) VALUES (?, ?, ?)"
        var ftsStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, ftsSQL, -1, &ftsStmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(ftsStmt) }

        for (_, node) in nodes {
            let idCStr = node.id.uuidString.cString(using: .utf8)
            let titleCStr = node.title.cString(using: .utf8)
            let bodyCStr = node.body.cString(using: .utf8)
            sqlite3_bind_text(ftsStmt, 1, idCStr, -1, nil)
            sqlite3_bind_text(ftsStmt, 2, titleCStr, -1, nil)
            sqlite3_bind_text(ftsStmt, 3, bodyCStr, -1, nil)
            sqlite3_step(ftsStmt)
            sqlite3_reset(ftsStmt)
        }
        NSLog("🔍 Rebuilt FTS5 index: \(nodes.count) nodes")
    }

    // MARK: - Relevance Decay

    func decayRelevance() {
        let now = Date.now.timeIntervalSince1970
        for (id, var node) in nodes {
            if node.pinned { continue }
            let daysSince = (now - node.lastAccessedAt.timeIntervalSince1970) / 86400
            let decay = exp(-daysSince / 30.0)
            node.relevance *= decay
            nodes[id] = node
            try? insertNode(node)
        }
        checkpoint()
        changeCount += 1
    }

    // MARK: - Private

    private func loadAll() throws {
        var stmt: OpaquePointer?

        // Load nodes
        guard sqlite3_prepare_v2(db, "SELECT * FROM nodes", -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }
        nodes = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let node = readNode(stmt) { nodes[node.id] = node }
        }
        sqlite3_finalize(stmt)

        // Load links
        guard sqlite3_prepare_v2(db, "SELECT * FROM links", -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }
        links = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let link = readLink(stmt) { links[link.id] = link }
        }
        sqlite3_finalize(stmt)
    }

    private func readNode(_ stmt: OpaquePointer?) -> MindNode? {
        guard let stmt,
              let idStr = sqlite3_column_text(stmt, 0),
              let typeStr = sqlite3_column_text(stmt, 1),
              let titleStr = sqlite3_column_text(stmt, 2)
        else { return nil }

        let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
        let type = NodeType(rawValue: String(cString: typeStr)) ?? .note
        let title = String(cString: titleStr)
        let body = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let relevance = sqlite3_column_double(stmt, 7)
        let confidence = sqlite3_column_double(stmt, 8)
        let status = NodeStatus(rawValue: sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? "active") ?? .active
        let pinned = sqlite3_column_int(stmt, 10) == 1
        let sourceOrigin = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let metaJSON = sqlite3_column_text(stmt, 12).map { String(cString: $0) } ?? "{}"
        let metadata = (try? JSONDecoder().decode([String: String].self, from: Data(metaJSON.utf8))) ?? [:]
        let dueDate: Date? = sqlite3_column_type(stmt, 13) != SQLITE_NULL
            ? Date(timeIntervalSince1970: sqlite3_column_double(stmt, 13)) : nil
        let accessCount = Int(sqlite3_column_int(stmt, 14))

        var node = MindNode(
            id: id, type: type, title: title, body: body,
            relevance: relevance, confidence: confidence, status: status,
            pinned: pinned, sourceOrigin: sourceOrigin, metadata: metadata, dueDate: dueDate
        )
        // Restore timestamps from DB (init sets them to .now)
        node.createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        node.updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
        node.lastAccessedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
        node.accessCount = accessCount
        return node
    }

    private func readLink(_ stmt: OpaquePointer?) -> MindLink? {
        guard let stmt,
              let idStr = sqlite3_column_text(stmt, 0),
              let srcStr = sqlite3_column_text(stmt, 1),
              let tgtStr = sqlite3_column_text(stmt, 2),
              let typeStr = sqlite3_column_text(stmt, 3)
        else { return nil }

        let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
        let src = UUID(uuidString: String(cString: srcStr)) ?? UUID()
        let tgt = UUID(uuidString: String(cString: tgtStr)) ?? UUID()
        let linkType = LinkType(rawValue: String(cString: typeStr)) ?? .relatedTo
        let weight = sqlite3_column_double(stmt, 4)

        return MindLink(id: id, sourceID: src, targetID: tgt, linkType: linkType, weight: weight)
    }

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errMsg) == SQLITE_OK else {
            if let errMsg {
                let msg = String(cString: errMsg)
                sqlite3_free(errMsg)
                NSLog("❌ SQL exec error: \(msg)")
            }
            throw StoreError.queryFailed
        }
    }
}

enum StoreError: Error {
    case openFailed
    case queryFailed
}
