import SwiftUI

/// Chat with your brain. The AI sees all your data and helps organize it.
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

                    if isThinking && !streamingText.isEmpty {
                        ChatBubble(message: ChatMessage(role: "assistant", content: streamingText))
                            .id("streaming")
                    } else if isThinking {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking...")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
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

                        let argsStr = function["arguments"] as? String ?? "{}"
                        let args = (try? JSONSerialization.jsonObject(with: Data(argsStr.utf8)) as? [String: Any]) ?? [:]

                        let toolResult = executeBrainTool(name: name, arguments: args, store: store)

                        let toolLabel = toolDisplayName(name)
                        messages.append(ChatMessage(role: "tool", content: "🔧 \(toolLabel): \(toolResult)"))
                    }

                    let finalMessages = [systemMsg] + messages
                    streamingText = ""
                    for try await chunk in client.streamChat(messages: finalMessages) {
                        streamingText += chunk
                    }

                    if !streamingText.isEmpty {
                        messages.append(ChatMessage(role: "assistant", content: streamingText))
                        streamingText = ""
                    }
                } else {
                    let streamMessages = [systemMsg] + messages
                    streamingText = ""
                    for try await chunk in client.streamChat(messages: streamMessages) {
                        streamingText += chunk
                    }

                    if !streamingText.isEmpty {
                        messages.append(ChatMessage(role: "assistant", content: streamingText))
                        streamingText = ""
                    }
                }

                isThinking = false

            } catch {
                messages.append(ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)"))
                isThinking = false
                streamingText = ""
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
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }
    private var isTool: Bool { message.role == "tool" }

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
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                if isUser { Spacer(minLength: 60) }

                if !isUser {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.top, 2)
                }

                Text(message.content)
                    .font(Theme.Fonts.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .fill(isUser ? Theme.Colors.accent.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    )

                if !isUser { Spacer(minLength: 60) }
            }
        }
    }
}
