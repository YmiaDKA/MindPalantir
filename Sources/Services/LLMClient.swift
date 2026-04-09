import Foundation

/// LLM client for OpenRouter (OpenAI-compatible API).
/// Free models with fallback chain. The "brain" context is injected as system prompt.
final class LLMClient: Sendable {
    private let apiKey: String
    private let baseURL = "https://openrouter.ai/api/v1"
    
    /// Free model fallback chain — OpenRouter handles fallback automatically
    static let models = [
        "google/gemma-4-26b-a4b-it:free",      // Gemma 4 — user's preference
        "google/gemma-3-27b-it:free",           // Gemma 3 27B — strong fallback
        "meta-llama/llama-3.3-70b-instruct:free", // Llama 3.3 — good quality
    ]
    
    /// Default model (first in chain)
    static let defaultModel = models[0]
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Chat Completion (non-streaming, with tool support)
    
    func chat(messages: [ChatMessage], tools: [[String: Any]]? = nil) async throws -> (content: String, toolCalls: [[String: Any]]?) {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MindPalantir/1.0", forHTTPHeaderField: "HTTP-Referer")
        request.timeoutInterval = 30
        
        var body: [String: Any] = [
            "models": Self.models,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": 1024,
            "temperature": 0.7,
        ]
        
        if let tools = tools {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "unknown"
            NSLog("❌ LLM error \(httpResponse.statusCode): \(errorText)")
            throw LLMError.apiError(httpResponse.statusCode, errorText)
        }
        
        return try parseResponse(data)
    }
    
    // MARK: - Streaming Chat
    
    func streamChat(messages: [ChatMessage], model: String? = nil) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: "\(self.baseURL)/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("MindPalantir/1.0", forHTTPHeaderField: "HTTP-Referer")
                    request.timeoutInterval = 60
                    
                    let body: [String: Any] = [
                        "models": Self.models,  // OpenRouter handles fallback
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "max_tokens": 1024,
                        "temperature": 0.7,
                        "stream": true,
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200
                    else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: LLMError.apiError(statusCode, "Stream failed"))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        guard jsonString != "[DONE]",
                              let data = jsonString.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String
                        else { continue }
                        
                        continuation.yield(content)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Parse Response
    
    private func parseResponse(_ data: Data) throws -> (content: String, toolCalls: [[String: Any]]?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any]
        else {
            throw LLMError.parseError
        }
        
        let content = message["content"] as? String ?? ""
        let toolCalls = message["tool_calls"] as? [[String: Any]]
        
        return (content, toolCalls)
    }
}

// MARK: - Types

struct ChatMessage: Codable, Sendable {
    let role: String  // "system", "user", "assistant"
    let content: String
}

enum LLMError: Error, LocalizedError {
    case invalidResponse
    case apiError(Int, String)
    case parseError
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from LLM"
        case .apiError(let code, let msg): "API error \(code): \(msg)"
        case .parseError: "Failed to parse LLM response"
        case .noAPIKey: "No API key configured"
        }
    }
}

// MARK: - API Key Storage

enum APIKeyStore {
    private static let keyKey = "openrouter_api_key"
    
    static var isConfigured: Bool {
        !(storedKey?.isEmpty ?? true)
    }
    
    static var storedKey: String? {
        UserDefaults.standard.string(forKey: keyKey)
    }
    
    static func save(_ key: String) {
        UserDefaults.standard.set(key, forKey: keyKey)
    }
    
    static func makeClient() -> LLMClient? {
        guard let key = storedKey, !key.isEmpty else { return nil }
        return LLMClient(apiKey: key)
    }
}
