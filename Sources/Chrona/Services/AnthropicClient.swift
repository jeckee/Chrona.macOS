import Foundation
import os

/// Anthropic Messages API（非 OpenAI 兼容路径）。
enum AnthropicClient {
    static let shared: AIClientProtocol = AnthropicClientImpl()
}

private struct AnthropicClientImpl: AIClientProtocol {
    private let session: URLSession = .shared
    private let logger = Logger(subsystem: "com.chrona.app", category: "Anthropic")
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let defaultModel = "claude-3-5-haiku-20241022"
    private let apiVersion = "2023-06-01"

    func testConnection(apiKey: String) async throws -> String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let body: [String: Any] = [
            "model": defaultModel,
            "max_tokens": 32,
            "messages": [["role": "user", "content": "Reply with OK only."]],
        ]
        return try await postMessages(apiKey: trimmed, body: body, timeout: 30)
    }

    func generateText(apiKey: String, modelId: String, prompt: String, forceJSONResponse: Bool) async throws -> String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let model = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : modelId
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "messages": [["role": "user", "content": prompt]],
        ]
        if forceJSONResponse {
            body["system"] = "You must respond with valid JSON only. No markdown fences, no explanation."
        }

        return try await postMessages(apiKey: trimmed, body: body, timeout: 120)
    }

    func streamText(apiKey: String, modelId: String, prompt: String) throws -> AsyncThrowingStream<String, Error> {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let model = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : modelId
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 800,
            "messages": [["role": "user", "content": prompt]],
            "stream": true,
        ]

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: apiURL, timeoutInterval: 180)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(trimmed, forHTTPHeaderField: "x-api-key")
                    request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (byteStream, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    guard http.statusCode == 200 else {
                        throw AIServiceError.providerError(statusCode: http.statusCode, message: nil)
                    }

                    for try await line in byteStream.lines {
                        if Task.isCancelled { break }
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedLine.hasPrefix("data:") else { continue }
                        let dataPart = trimmedLine.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                        guard let data = dataPart.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        if let type = json["type"] as? String, type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let text = delta["text"] as? String,
                           !text.isEmpty {
                            continuation.yield(text)
                        }
                    }

                    if Task.isCancelled { throw CancellationError() }
                    continuation.finish()
                } catch let urlError as URLError {
                    if urlError.code == .timedOut {
                        continuation.finish(throwing: AIServiceError.timeout)
                    } else {
                        continuation.finish(throwing: AIServiceError.networkFailed(underlying: urlError))
                    }
                } catch let ai as AIServiceError {
                    continuation.finish(throwing: ai)
                } catch {
                    logger.error("Anthropic stream failed")
                    continuation.finish(throwing: AIServiceError.unknown(underlying: error))
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    private func postMessages(apiKey: String, body: [String: Any], timeout: TimeInterval) async throws -> String {
        var request = URLRequest(url: apiURL, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            if http.statusCode != 200 {
                let msg = Self.extractErrorMessage(from: data)
                if http.statusCode == 401 || http.statusCode == 403 {
                    throw AIServiceError.authenticationFailed
                }
                throw AIServiceError.providerError(statusCode: http.statusCode, message: msg)
            }
            let text = try Self.extractAssistantText(from: data)
            let out = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !out.isEmpty else { throw AIServiceError.invalidResponse }
            return out
        } catch let urlError as URLError {
            if urlError.code == .timedOut { throw AIServiceError.timeout }
            throw AIServiceError.networkFailed(underlying: urlError)
        } catch let ai as AIServiceError {
            throw ai
        } catch {
            throw AIServiceError.unknown(underlying: error)
        }
    }

    private static func extractAssistantText(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw AIServiceError.invalidResponse
        }
        var parts: [String] = []
        for block in content {
            if let type = block["type"] as? String, type == "text",
               let text = block["text"] as? String {
                parts.append(text)
            }
        }
        guard !parts.isEmpty else { throw AIServiceError.invalidResponse }
        return parts.joined()
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = json["error"] as? [String: Any] {
            return (err["message"] as? String) ?? (err["type"] as? String)
        }
        return json["message"] as? String
    }

}
