import Foundation

/// Tool definitions for the LLM (OpenAI function calling format)
nonisolated(unsafe) let brainToolDefinitions: [[String: Any]] = [
    [
        "type": "function",
        "function": [
            "name": "create_node",
            "description": "Create a new item in the user's brain.",
            "parameters": [
                "type": "object",
                "properties": [
                    "type": ["type": "string", "enum": ["project", "task", "note", "person", "event", "source"]],
                    "title": ["type": "string", "description": "The title/name"],
                    "body": ["type": "string", "description": "Optional description"],
                ],
                "required": ["type", "title"]
            ]
        ]
    ],
    [
        "type": "function",
        "function": [
            "name": "search_brain",
            "description": "Search the user's brain for items.",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "What to search for"],
                ],
                "required": ["query"]
            ]
        ]
    ],
    [
        "type": "function",
        "function": [
            "name": "create_link",
            "description": "Create a relationship between two items.",
            "parameters": [
                "type": "object",
                "properties": [
                    "source_title": ["type": "string"],
                    "target_title": ["type": "string"],
                    "link_type": ["type": "string", "enum": ["belongsTo", "relatedTo", "mentions", "fromSource"]],
                ],
                "required": ["source_title", "target_title", "link_type"]
            ]
        ]
    ],
    [
        "type": "function",
        "function": [
            "name": "update_node",
            "description": "Update an item's status, relevance, or confidence.",
            "parameters": [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "status": ["type": "string", "enum": ["active", "completed", "archived", "draft", "waiting"]],
                    "relevance": ["type": "number"],
                    "confidence": ["type": "number"],
                ],
                "required": ["title"]
            ]
        ]
    ],
]

nonisolated(unsafe) let brainToolDefinitionsExtra: [[String: Any]] = [
    [
        "type": "function",
        "function": [
            "name": "delete_node",
            "description": "Delete an item from the brain by title. Use carefully.",
            "parameters": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "Exact title of item to delete"],
                ],
                "required": ["title"]
            ]
        ]
    ],
    [
        "type": "function",
        "function": [
            "name": "list_nodes",
            "description": "List all items of a specific type, optionally filtered by status.",
            "parameters": [
                "type": "object",
                "properties": [
                    "type": ["type": "string", "enum": ["project", "task", "note", "person", "event", "source"]],
                    "status": ["type": "string", "enum": ["active", "completed", "archived", "draft", "waiting"]],
                    "limit": ["type": "integer", "description": "Max items to return (default 10)"],
                ],
                "required": ["type"]
            ]
        ]
    ],
    [
        "type": "function",
        "function": [
            "name": "find_connections",
            "description": "Find all items connected to a specific item.",
            "parameters": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "Title of the item to find connections for"],
                ],
                "required": ["title"]
            ]
        ]
    ],
    [
        "type": "function",
        "function": [
            "name": "get_node_details",
            "description": "Get full details of an item including body, scores, connections, and metadata.",
            "parameters": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "Title of the item"],
                ],
                "required": ["title"]
            ]
        ]
    ],
]

/// Execute a tool call against the store
@MainActor
func executeBrainTool(name: String, arguments: [String: Any], store: NodeStore) -> String {
    switch name {
    case "create_node":
        guard let typeStr = arguments["type"] as? String,
              let type = NodeType(rawValue: typeStr),
              let title = arguments["title"] as? String
        else { return "Error: missing required fields" }
        let node = MindNode(type: type, title: title, body: arguments["body"] as? String ?? "", sourceOrigin: "ai_chat")
        try? store.insertNode(node)
        return "Created \(type.rawValue): '\(title)'"
        
    case "search_brain":
        guard let query = arguments["query"] as? String else { return "Error: missing query" }
        let results = store.search(query, limit: 5)
        if results.isEmpty { return "No results for '\(query)'" }
        return results.map { "\($0.type.emoji) \($0.title) [\($0.status.rawValue), relevance: \(Int($0.relevance * 100))%]" }.joined(separator: "\n")
        
    case "create_link":
        guard let src = arguments["source_title"] as? String,
              let tgt = arguments["target_title"] as? String,
              let lt = arguments["link_type"] as? String,
              let linkType = LinkType(rawValue: lt),
              let source = store.nodes.values.first(where: { $0.title == src }),
              let target = store.nodes.values.first(where: { $0.title == tgt })
        else { return "Error: items not found or invalid link type" }
        try? store.insertLink(MindLink(sourceID: source.id, targetID: target.id, linkType: linkType))
        return "Linked: '\(src)' → '\(tgt)' (\(lt))"
        
    case "update_node":
        guard let title = arguments["title"] as? String,
              var node = store.nodes.values.first(where: { $0.title == title })
        else { return "Error: '\(arguments["title"] ?? "")' not found" }
        if let s = arguments["status"] as? String, let st = NodeStatus(rawValue: s) { node.status = st }
        if let r = arguments["relevance"] as? Double { node.relevance = max(0, min(1, r)) }
        if let c = arguments["confidence"] as? Double { node.confidence = max(0, min(1, c)) }
        node.updatedAt = .now
        try? store.insertNode(node)
        return "Updated '\(title)'"
        
    case "delete_node":
        guard let title = arguments["title"] as? String,
              let node = store.nodes.values.first(where: { $0.title == title })
        else { return "Error: '\(arguments["title"] ?? "")' not found" }
        try? store.deleteNode(id: node.id)
        return "Deleted '\(title)' and its links"

    case "list_nodes":
        guard let typeStr = arguments["type"] as? String,
              let type = NodeType(rawValue: typeStr)
        else { return "Error: missing or invalid type" }
        let statusFilter = (arguments["status"] as? String).flatMap(NodeStatus.init)
        let limit = arguments["limit"] as? Int ?? 10
        var nodes = store.nodes(ofType: type)
        if let status = statusFilter {
            nodes = nodes.filter { $0.status == status }
        }
        if nodes.isEmpty { return "No \(type.rawValue)s\(statusFilter.map { " with status \($0.rawValue)" } ?? "")" }
        return nodes.prefix(limit).map {
            "\($0.type.emoji) \($0.title) [\($0.status.rawValue), relevance: \(Int($0.relevance * 100))%]"
        }.joined(separator: "\n")

    case "find_connections":
        guard let title = arguments["title"] as? String,
              let node = store.nodes.values.first(where: { $0.title == title })
        else { return "Error: '\(arguments["title"] ?? "")' not found" }
        let connected = store.connectedNodes(for: node.id)
        if connected.isEmpty { return "'\(title)' has no connections" }
        let linkTypes = store.linksFor(nodeID: node.id)
        return connected.map { c in
            let link = linkTypes.first { $0.sourceID == c.id || $0.targetID == c.id }
            return "\(c.type.emoji) \(c.title) [\(link?.linkType.rawValue ?? "related")]"
        }.joined(separator: "\n")

    case "get_node_details":
        guard let title = arguments["title"] as? String,
              let node = store.nodes.values.first(where: { $0.title == title })
        else { return "Error: '\(arguments["title"] ?? "")' not found" }
        var lines = ["\(node.type.emoji) \(node.title)"]
        lines.append("Status: \(node.status.rawValue) | Relevance: \(Int(node.relevance * 100))% | Confidence: \(Int(node.confidence * 100))%")
        if !node.body.isEmpty { lines.append("Details: \(node.body)") }
        if let origin = node.sourceOrigin { lines.append("Source: \(origin)") }
        if let due = node.dueDate { lines.append("Due: \(due.formatted(date: .abbreviated, time: .omitted))") }
        if node.pinned { lines.append("📌 Pinned") }
        let connections = store.connectedNodes(for: node.id)
        if !connections.isEmpty {
            lines.append("Connections (\(connections.count)):")
            for c in connections.prefix(8) { lines.append("  \(c.type.emoji) \(c.title)") }
        }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        lines.append("Created: \(df.string(from: node.createdAt))")
        lines.append("Updated: \(df.string(from: node.updatedAt))")
        return lines.joined(separator: "\n")

    default:
        return "Unknown tool: \(name)"
    }
}

/// All tool definitions combined
var allBrainToolDefinitions: [[String: Any]] {
    brainToolDefinitions + brainToolDefinitionsExtra
}
