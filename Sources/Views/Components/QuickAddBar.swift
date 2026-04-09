import SwiftUI

/// Quick add with smart type detection. Main capture mechanism.
struct QuickAddBar: View {
    @Environment(NodeStore.self) private var store
    @State private var text = ""
    @State private var selectedType: NodeType = .note
    @State private var autoDetectedType: NodeType?
    @State private var addedFeedback = false
    var focusedProject: MindNode? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Type selector
            Menu {
                ForEach(NodeType.allCases, id: \.self) { type in
                    Button { selectedType = type } label: {
                        HStack {
                            Image(systemName: type.sfIcon)
                            Text(type.rawValue.capitalized)
                            if autoDetectedType == type && selectedType != type {
                                Text("(auto)")
                                    .foregroundStyle(.secondary)
                                    .font(Theme.Fonts.caption)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: selectedType.sfIcon)
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32)

            // Text field — multiline support (first line = title, rest = body)
            TextField("Quick add...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .lineLimit(1...4)
                .onSubmit { addNode() }
                .onChange(of: text) { _, newText in
                    autoDetectedType = detectType(newText)
                    if let detected = autoDetectedType {
                        selectedType = detected
                    }
                }
            
            // Add button or feedback
            if addedFeedback {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else if !text.isEmpty {
                Button { addNode() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusQuickAdd"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
    
    // MARK: - Smart Type Detection
    
    private func detectType(_ text: String) -> NodeType? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        
        // URL → source
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("www.") {
            return .source
        }
        
        // @name → person
        if trimmed.hasPrefix("@") {
            return .person
        }
        
        // "todo:" or "- [ ]" → task
        if trimmed.hasPrefix("todo:") || trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("task:") {
            return .task
        }
        
        // Date patterns → event
        let dateWords = ["meeting", "call", "deadline", "due", "scheduled", "appointment"]
        if dateWords.contains(where: { trimmed.contains($0) }) {
            return .event
        }
        
        // "project:" → project
        if trimmed.hasPrefix("project:") || trimmed.hasPrefix("proj:") {
            return .project
        }
        
        return nil
    }
    
    // MARK: - Add Node
    
    private func addNode() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Split into title + body (first line = title, rest = body)
        let lines = trimmed.components(separatedBy: .newlines)
        var title = lines.first ?? trimmed
        let body = lines.count > 1 ? lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespaces) : ""

        // Clean up title based on type prefix
        if selectedType == .task {
            title = title
                .replacingOccurrences(of: "todo:", with: "")
                .replacingOccurrences(of: "task:", with: "")
                .replacingOccurrences(of: "- [ ]", with: "")
                .trimmingCharacters(in: .whitespaces)
        } else if selectedType == .person {
            title = title.hasPrefix("@") ? String(title.dropFirst()) : title
        } else if selectedType == .project {
            title = title
                .replacingOccurrences(of: "project:", with: "")
                .replacingOccurrences(of: "proj:", with: "")
                .trimmingCharacters(in: .whitespaces)
        }

        let node = MindNode(
            type: selectedType,
            title: title,
            body: body,
            relevance: 0.7,
            confidence: 0.8,
            sourceOrigin: "quick_add"
        )
        try? store.insertNode(node)
        
        // Auto-link to focused project
        if let project = focusedProject {
            let link = MindLink(sourceID: project.id, targetID: node.id, linkType: .belongsTo)
            try? store.insertLink(link)
        }
        
        text = ""
        selectedType = .note
        autoDetectedType = nil
        
        // Feedback
        withAnimation {
            addedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                addedFeedback = false
            }
        }
    }
}
