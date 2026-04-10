import SwiftUI

/// Chat with your brain. The AI sees all your data and helps organize it.
/// Enhanced streaming: animated thinking dots, blinking cursor, word-by-word flow.
struct ChatView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    var focusedProject: MindNode? = nil
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var llmClient: LLMClient?
    @State private var apiKeyInput = ""
    @State private var showAPIKeyPrompt = false
    @State private var streamingText = ""
    @State private var currentTask: Task<Void, Never>?
    @State private var toolCallsInProgress: [String] = []
    @State private var showCursor = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            if messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            Divider()

            inputBar
        }
        .navigationTitle("Chat")
        .onAppear { loadAPIKey() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(Theme.Colors.accent)
            Text("Brain Assistant")
                .font(Theme.Fonts.headline)

            Spacer()

            if let proj = focusedProject {
                Label(proj.title, systemImage: "folder.fill")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.typeColor(.project))
                    .lineLimit(1)
            }

            Text("\(store.nodes.count) nodes")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.tertiary)

            if llmClient == nil {
                Button("Set API Key") { showAPIKeyPrompt = true }
                    .font(Theme.Fonts.caption)
                    .buttonStyle(.bordered)
                    .tint(.orange)
            }

            Button { clearChat() } label: {
                Image(systemName: "trash")
                    .font(Theme.Fonts.caption)
            }
            .buttonStyle(.plain)
            .help("Clear conversation")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .alert("OpenRouter API Key", isPresented: $showAPIKeyPrompt) {
            SecureField("sk-or-...", text: $apiKeyInput)
            Button("Save") { saveAPIKey() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Get a key at openrouter.ai/settings/keys")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))

            Text("Talk to your brain")
                .font(Theme.Fonts.largeTitle)
                .foregroundStyle(.secondary)

            VStack(spacing: Theme.Spacing.sm) {
                suggestionChip(icon: "folder", "What projects am I working on?")
                suggestionChip(icon: "star", "What's most important right now?")
                suggestionChip(icon: "link", "Find connections I'm missing")
                suggestionChip(icon: "checklist", "Help me organize my tasks")
                suggestionChip(icon: "calendar", "What should I focus on today?")
            }

            if llmClient == nil {
                Label("Set an OpenRouter API key to start", systemImage: "key")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, Theme.Spacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func suggestionChip(icon: String, _ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Label(text, systemImage: icon)
                .font(Theme.Fonts.caption)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs + 2)
                .background(Theme.Colors.accent.opacity(0.08), in: Capsule())
                .foregroundStyle(Theme.Colors.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(messages.indices, id: \.self) { idx in
                        ChatBubble(message: messages[idx])
                            .id(idx)
                    }

                    // Tool calls in progress — animated chips
                    if !toolCallsInProgress.isEmpty {
                        ForEach(toolCallsInProgress, id: \.self) { toolName in
                            ToolCallChip(toolName: toolName)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .id("tool_\(toolName)")
                        }
                    }

                    // Streaming response with cursor
                    if isThinking && !streamingText.isEmpty {
                        StreamingBubble(text: streamingText, showCursor: showCursor)
                            .id("streaming")
                    } else if isThinking && toolCallsInProgress.isEmpty {
                        ThinkingDots()
                            .padding(.horizontal, Theme.Spacing.lg)
                            .id("thinking")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(messages.count - 1, anchor: .bottom)
                }
            }
            .onChange(of: streamingText) { _, _ in
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .onChange(of: toolCallsInProgress.count) { _, _ in
                if let lastTool = toolCallsInProgress.last {
                    withAnimation {
                        proxy.scrollTo("tool_\(lastTool)", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Ask about your brain...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.Fonts.body)
                .lineLimit(1...4)
                .onSubmit { sendMessage() }

            if !inputText.isEmpty || isThinking {
                Button {
                    if isThinking {
                        currentTask?.cancel()
                        currentTask = nil
                        isThinking = false
                        showCursor = false
                        toolCallsInProgress = []
                        if !streamingText.isEmpty {
                            messages.append(ChatMessage(role: "assistant", content: streamingText))
                            streamingText = ""
                        }
                    } else {
                        sendMessage()
                    }
                } label: {
                    Image(systemName: isThinking ? "stop.circle" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.accent)
                }
                .buttonStyle(.plain)
                .disabled(!isThinking && llmClient == nil)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.ultraThinMaterial)
    }

    // MARK: - Send Message

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let client = llmClient else { return }

        inputText = ""
        messages.append(ChatMessage(role: "user", content: text))

        isThinking = true
        streamingText = ""
        toolCallsInProgress = []

        currentTask?.cancel()
        currentTask = Task { @MainActor in
            do {
                let routedContext = BrainContext.route(question: text, store: store, focusedProject: focusedProject)
                let systemMsg = ChatMessage(role: "system", content: routedContext)
                let fullMessages = [systemMsg] + messages

                let result = try await client.chat(
                    messages: fullMessages,
                    tools: allBrainToolDefinitions
                )

                if let toolCalls = result.toolCalls, !toolCalls.isEmpty {
                    let assistantContent = result.content
                    if !assistantContent.isEmpty {
                        messages.append(ChatMessage(role: "assistant", content: assistantContent))
                    }

                    for call in toolCalls {
                        guard let function = call["function"] as? [String: Any],
                              let name = function["name"] as? String
                        else { continue }

                        // Show tool call chip
                        let toolLabel = toolDisplayName(name)
                        toolCallsInProgress.append(toolLabel)

                        let argsStr = function["arguments"] as? String ?? "{}"
                        let args = (try? JSONSerialization.jsonObject(with: Data(argsStr.utf8)) as? [String: Any]) ?? [:]

                        let toolResult = executeBrainTool(name: name, arguments: args, store: store)

                        // Brief delay so chip is visible
                        try? await Task.sleep(for: .milliseconds(300))

                        // Remove chip, add result message
                        toolCallsInProgress.removeAll { $0 == toolLabel }
                        messages.append(ChatMessage(role: "tool", content: "✅ \(toolLabel): \(toolResult)"))
                    }

                    let finalMessages = [systemMsg] + messages
                    streamingText = ""
                    showCursor = true
                    for try await chunk in client.streamChat(messages: finalMessages) {
                        streamingText += chunk
                    }

                    if !streamingText.isEmpty {
                        messages.append(ChatMessage(role: "assistant", content: streamingText))
                        streamingText = ""
                    }
                    showCursor = false
                } else {
                    let streamMessages = [systemMsg] + messages
                    streamingText = ""
                    showCursor = true
                    for try await chunk in client.streamChat(messages: streamMessages) {
                        streamingText += chunk
                    }

                    if !streamingText.isEmpty {
                        messages.append(ChatMessage(role: "assistant", content: streamingText))
                        streamingText = ""
                    }
                    showCursor = false
                }

                isThinking = false

            } catch {
                messages.append(ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)"))
                isThinking = false
                streamingText = ""
                showCursor = false
            }
        }
    }

    private func toolDisplayName(_ name: String) -> String {
        switch name {
        case "create_node": "Creating item"
        case "search_brain": "Searching"
        case "create_link": "Creating link"
        case "update_node": "Updating item"
        case "delete_node": "Deleting item"
        case "list_nodes": "Listing items"
        case "find_connections": "Finding connections"
        case "get_node_details": "Getting details"
        default: name
        }
    }

    // MARK: - API Key Management

    private func loadAPIKey() {
        llmClient = APIKeyStore.makeClient()
    }

    private func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        APIKeyStore.save(trimmed)
        llmClient = LLMClient(apiKey: trimmed)
        apiKeyInput = ""
    }

    private func clearChat() {
        currentTask?.cancel()
        currentTask = nil
        messages = []
        streamingText = ""
        isThinking = false
        showCursor = false
        toolCallsInProgress = []
    }
}

// MARK: - Thinking Dots (animated)

struct ThinkingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .offset(y: animating ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .onAppear { animating = true }

            Text("Thinking")
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Streaming Bubble (with blinking cursor + markdown)

struct StreamingBubble: View {
    let text: String
    let showCursor: Bool
    @State private var cursorVisible = true

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 0) {
                MarkdownText(text)
                    .textSelection(.enabled)

                if showCursor {
                    Text(cursorVisible ? "▌" : " ")
                        .foregroundStyle(Theme.Colors.accent)
                        .animation(.none, value: cursorVisible)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            Spacer(minLength: 60)
        }
        .onAppear {
            if showCursor {
                startBlinking()
            }
        }
        .onChange(of: showCursor) { _, newValue in
            if newValue {
                startBlinking()
            }
        }
    }

    private func startBlinking() {
        Task { @MainActor in
            while showCursor {
                try? await Task.sleep(for: .milliseconds(530))
                withAnimation(.easeInOut(duration: 0.1)) {
                    cursorVisible.toggle()
                }
            }
        }
    }
}

// MARK: - Tool Call Chip (animated)

struct ToolCallChip: View {
    let toolName: String
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 6) {
            // Animated spinner
            ProgressView()
                .controlSize(.mini)

            Text(toolName)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .fill(Theme.Colors.accent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .strokeBorder(Theme.Colors.accent.opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - Chat Bubble (markdown + copy + timestamp)

struct ChatBubble: View {
    let message: ChatMessage
    @State private var isHovered = false
    @State private var showCopied = false

    private var isUser: Bool { message.role == "user" }
    private var isTool: Bool { message.role == "tool" }
    private var isAssistant: Bool { message.role == "assistant" }

    var body: some View {
        if isTool {
            HStack(spacing: 6) {
                Text(message.content)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                if isUser { Spacer(minLength: 60) }

                if !isUser {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.top, 2)
                }

                VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                    // Message content — markdown for assistant, plain for user
                    Group {
                        if isAssistant {
                            MarkdownText(message.content)
                        } else {
                            Text(message.content)
                                .font(Theme.Fonts.body)
                        }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

                    // Bottom row: timestamp + copy
                    HStack(spacing: Theme.Spacing.xs) {
                        if !isUser {
                            Text(message.timestamp, style: .time)
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer(minLength: 0)

                        if isHovered || showCopied {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                                withAnimation { showCopied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { showCopied = false }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 9))
                                    if showCopied {
                                        Text("Copied")
                                            .font(Theme.Fonts.tiny)
                                    }
                                }
                                .foregroundStyle(showCopied ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }

                        if isUser {
                            Text(message.timestamp, style: .time)
                                .font(Theme.Fonts.tiny)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .fill(isUser ? Theme.Colors.accent.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }

                if !isUser { Spacer(minLength: 60) }
            }
            .transition(.opacity.combined(with: .move(edge: isUser ? .trailing : .leading)))
        }
    }
}

// MARK: - Markdown Text Renderer

/// Renders markdown using AttributedString — bold, italic, code, links, lists.
/// Falls back to plain text if parsing fails (e.g., mid-stream incomplete markdown).
struct MarkdownText: View {
    let content: String

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        if let attributed = try? AttributedString(markdown: content, options: AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )) {
            Text(attributed)
                .font(Theme.Fonts.body)
        } else {
            Text(content)
                .font(Theme.Fonts.body)
        }
    }
}
