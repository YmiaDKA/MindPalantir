import Foundation

/// LLM client for OpenRouter (OpenAI-compatible API).
/// Provides the "brain" context to the AI so it can reason about your data.
final class LLMClient: Sendable {
    private let apiKey: String
    private let baseURL = "https://openrouter.ai/api/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Chat Completion
    
    /// Send a conversation with brain context to the LLM.
    /// Returns the AI's response text.
    func chat(messages: [ChatMessage], model: String = "google/gemini-2.0-flash-001") async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MindPalantir/1.0", forHTTPHeaderField: "HTTP-Referer")
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": 1024,
            "temperature": 0.7,
        ]
        
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
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.parseError
        }
        
        return content
    }
    
    /// Stream a chat response (for real-time display).
    func streamChat(messages: [ChatMessage], model: String = "google/gemini-2.0-flash-001") -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: "\(baseURL)/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("MindPalantir/1.0", forHTTPHeaderField: "HTTP-Referer")
                    
                    let body: [String: Any] = [
                        "model": model,
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
