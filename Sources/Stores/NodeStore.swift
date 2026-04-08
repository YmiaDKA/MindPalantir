import Foundation
import SQLite3

// SQLITE_TRANSIENT is not exported as a constant — define it
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// The single persistent store. One thing exists once.
/// Views are queries on this store, not copies.
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
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { throw StoreError.openFailed }
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA foreign_keys=ON")
        try createTables()
        try loadAll()
    }

    func close() {
        sqlite3_close(db)
        db = nil
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
            due_date REAL
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
            dedupe_key TEXT NOT NULL UNIQUE,
            FOREIGN KEY (source_id) REFERENCES nodes(id) ON DELETE CASCADE,
            FOREIGN KEY (target_id) REFERENCES nodes(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_links_source ON links(source_id);
        CREATE INDEX IF NOT EXISTS idx_links_target ON links(target_id);
        CREATE INDEX IF NOT EXISTS idx_links_dedupe ON links(dedupe_key);
        """)
    }

    // MARK: - Node CRUD

    func insertNode(_ node: MindNode) throws {
        let sql = """
        INSERT OR REPLACE INTO nodes
        (id, type, title, body, created_at, updated_at, last_accessed_at,
         relevance, confidence, status, pinned, source_origin, metadata, due_date)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw StoreError.queryFailed }
        defer { sqlite3_finalize(stmt) }

        let metaJSON = String(data: (try? JSONEncoder().encode(node.metadata)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}"

        sqlite3_bind_text(stmt, 1, node.id.uuidString, -1, nil)
        sqlite3_bind_text(stmt, 2, node.type.rawValue, -1, nil)
        sqlite3_bind_text(stmt, 3, node.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, node.body, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 5, node.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 6, node.updatedAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 7, node.lastAccessedAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 8, node.relevance)
        sqlite3_bind_double(stmt, 9, node.confidence)
        sqlite3_bind_text(stmt, 10, node.status.rawValue, -1, nil)
        sqlite3_bind_int(stmt, 11, node.pinned ? 1 : 0)
        sqlite3_bind_text(stmt, 12, node.sourceOrigin ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 13, metaJSON, -1, SQLITE_TRANSIENT)
        if let due = node.dueDate {
            sqlite3_bind_double(stmt, 14, due.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 14)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw StoreError.queryFailed }
        nodes[node.id] = node
        changeCount += 1
    }

    func deleteNode(id: UUID) throws {
        try exec("DELETE FROM links WHERE source_id='\(id.uuidString)' OR target_id='\(id.uuidString)'")
        try exec("DELETE FROM nodes WHERE id='\(id.uuidString)'")
        nodes.removeValue(forKey: id)
        links = links.filter { $0.value.sourceID != id && $0.value.targetID != id }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
        changeCount += 1
    }

    // MARK: - Link CRUD

    func insertLink(_ link: MindLink) throws {
        let sql = """
        INSERT OR IGNORE INTO links (id, source_id, target_id, link_type, weight, created_at, dedupe_key)
        VALUES (?,?,?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw StoreError.queryFailed }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, link.id.uuidString, -1, nil)
        sqlite3_bind_text(stmt, 2, link.sourceID.uuidString, -1, nil)
        sqlite3_bind_text(stmt, 3, link.targetID.uuidString, -1, nil)
        sqlite3_bind_text(stmt, 4, link.linkType.rawValue, -1, nil)
        sqlite3_bind_double(stmt, 5, link.weight)
        sqlite3_bind_double(stmt, 6, link.createdAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 7, link.dedupeKey, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw StoreError.queryFailed }
        links[link.id] = link
        changeCount += 1
    }

    func deleteLink(id: UUID) throws {
        try exec("DELETE FROM links WHERE id='\(id.uuidString)'")
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
        let _ = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))  // createdAt
        let _ = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))  // updatedAt
        let _ = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))  // lastAccessed
        let relevance = sqlite3_column_double(stmt, 7)
        let confidence = sqlite3_column_double(stmt, 8)
        let status = NodeStatus(rawValue: sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? "active") ?? .active
        let pinned = sqlite3_column_int(stmt, 10) == 1
        let sourceOrigin = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let metaJSON = sqlite3_column_text(stmt, 12).map { String(cString: $0) } ?? "{}"
        let metadata = (try? JSONDecoder().decode([String: String].self, from: Data(metaJSON.utf8))) ?? [:]
        let dueDate: Date? = sqlite3_column_type(stmt, 13) != SQLITE_NULL
            ? Date(timeIntervalSince1970: sqlite3_column_double(stmt, 13)) : nil

        return MindNode(
            id: id, type: type, title: title, body: body,
            relevance: relevance, confidence: confidence, status: status,
            pinned: pinned, sourceOrigin: sourceOrigin, metadata: metadata, dueDate: dueDate
        )
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
            sqlite3_free(errMsg)
            throw StoreError.queryFailed
        }
    }
}

enum StoreError: Error {
    case openFailed
    case queryFailed
}
