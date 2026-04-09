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
        let results = store.nodes.values
            .filter { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
            .sorted { $0.relevance > $1.relevance }
            .prefix(5)
        if results.isEmpty { return "No results for '\(query)'" }
        return results.map { "\($0.type.icon) \($0.title) [\($0.status.rawValue)]" }.joined(separator: "\n")
        
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
        
    default:
        return "Unknown tool: \(name)"
    }
}
