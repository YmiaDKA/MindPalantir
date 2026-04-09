import SwiftUI

/// Chat with your brain. The AI sees all your data and helps organize it.
struct ChatView: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var llmClient: LLMClient?
    @State private var apiKeyInput = ""
    @State private var showAPIKeyPrompt = false
    @State private var streamingText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            Divider()
            
            // Messages
            if messages.isEmpty {
                emptyState
            } else {
                messageList
            }
            
            Divider()
            
            // Input
            inputBar
        }
        .navigationTitle("Chat")
        .onAppear { loadAPIKey() }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.purple)
            Text("Brain Assistant")
                .font(.headline)
            
            Spacer()
            
            if llmClient == nil {
                Button("Set API Key") { showAPIKeyPrompt = true }
                    .font(.caption)
            }
            
            Button { clearChat() } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Clear conversation")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .alert("OpenRouter API Key", isPresented: $showAPIKeyPrompt) {
            TextField("sk-or-...", text: $apiKeyInput)
            Button("Save") { saveAPIKey() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Get a key at openrouter.ai/settings/keys")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.purple.opacity(0.4))
            
            Text("Talk to your brain")
                .font(.title2.bold())
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                suggestionChip("What projects am I working on?")
                suggestionChip("What's most important right now?")
                suggestionChip("Find connections I'm missing")
                suggestionChip("Help me organize my tasks")
                suggestionChip("What should I focus on today?")
            }
            
            if llmClient == nil {
                Text("⚠️ Set an OpenRouter API key to start")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func suggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.purple.opacity(0.08), in: Capsule())
                .foregroundStyle(.purple)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Message List
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
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
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
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
        HStack(spacing: 8) {
            TextField("Ask about your brain...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .onSubmit { sendMessage() }
            
            if !inputText.isEmpty {
                Button { sendMessage() } label: {
                    Image(systemName: isThinking ? "stop.circle" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .disabled(llmClient == nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Send Message (with tool calling)
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let client = llmClient else { return }
        
        inputText = ""
        messages.append(ChatMessage(role: "user", content: text))
        
        isThinking = true
        streamingText = ""
        
        Task { @MainActor in
            do {
                let brainContext = BrainContext.build(from: store)
                let systemMsg = ChatMessage(role: "system", content: brainContext)
                let fullMessages = [systemMsg] + messages
                
                // First call with tools
                let result = try await client.chat(
                    messages: fullMessages,
                    tools: brainToolDefinitions
                )
                
                // If AI wants to use tools, execute them
                if let toolCalls = result.toolCalls, !toolCalls.isEmpty {
                    // Add assistant message with tool calls
                    let assistantContent = result.content
                    messages.append(ChatMessage(role: "assistant", content: assistantContent.isEmpty ? "Let me check that..." : assistantContent))
                    
                    // Execute each tool
                    for call in toolCalls {
                        guard let function = call["function"] as? [String: Any],
                              let name = function["name"] as? String
                        else { continue }
                        
                        let argsStr = function["arguments"] as? String ?? "{}"
                        let args = (try? JSONSerialization.jsonObject(with: Data(argsStr.utf8)) as? [String: Any]) ?? [:]
                        
                        let toolResult = executeBrainTool(name: name, arguments: args, store: store)
                        
                        // Add tool result as message
                        messages.append(ChatMessage(role: "tool", content: toolResult))
                    }
                    
                    // Second call to get final response
                    let finalMessages = [systemMsg] + messages
                    let finalResult = try await client.chat(messages: finalMessages)
                    
                    if !finalResult.content.isEmpty {
                        messages.append(ChatMessage(role: "assistant", content: finalResult.content))
                    }
                } else {
                    // No tool calls, just show the response
                    if !result.content.isEmpty {
                        messages.append(ChatMessage(role: "assistant", content: result.content))
                    }
                }
                
                isThinking = false
                
            } catch {
                messages.append(ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)"))
                isThinking = false
            }
        }
    }
    
    // MARK: - Auto-create nodes from AI responses
    
    private func processSuggestions(_ response: String) {
        // Look for patterns like "I'd suggest creating a task: ..."
        // or "You should add a note about ..."
        // For now, just detect if the AI mentions creating something
        
        let taskPatterns = [
            "suggest creating a task",
            "you should add a task",
            "I recommend creating",
        ]
        
        for pattern in taskPatterns {
            if response.lowercased().contains(pattern.lowercased()) {
                // The AI suggested something — the user can tell us to create it
                // Don't auto-create, just make it easy
                break
            }
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
        messages = []
        streamingText = ""
        isThinking = false
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    
    private var isUser: Bool { message.role == "user" }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 60) }
            
            if !isUser {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)
                    .padding(.top, 2)
            }
            
            Text(message.content)
                .font(.subheadline)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isUser ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                )
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}
