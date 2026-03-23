import Foundation
import os

final class AIService: AIServiceProtocol {
    static let shared = AIService()

    private let session: URLSession
    private let logger = Logger(subsystem: "com.chrona.app", category: "AIConnectionTest")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func testConnection(provider: AIProvider, apiKey: String) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let prompt = "Return only: OK"
        switch provider {
        case .qwen:
            // Qwen DashScope: OpenAI-compatible chat completions
            let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
            let url = URL(string: "\(baseURL)/chat/completions")!
            let body: [String: Any] = [
                "model": provider.defaultModelId,
                "messages": [["role": "user", "content": prompt]],
                "temperature": 0,
                "max_tokens": 16
            ]
            return try await sendChatCompletion(url: url, apiKey: trimmedKey, body: body)

        case .deepseek:
            // DeepSeek: OpenAI-compatible chat completions
            let baseURL = "https://api.deepseek.com"
            let url = URL(string: "\(baseURL)/chat/completions")!
            let body: [String: Any] = [
                "model": provider.defaultModelId,
                "messages": [["role": "user", "content": prompt]],
                "temperature": 0,
                "max_tokens": 16,
                "stream": false
            ]
            return try await sendChatCompletion(url: url, apiKey: trimmedKey, body: body)
        }
    }

    func runChatCompletion(
        provider: AIProvider,
        apiKey: String,
        modelId: String,
        prompt: String,
        forceJSONResponse: Bool
    ) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw AIServiceError.apiKeyEmpty }
        let resolvedModelId = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultModelId
            : modelId

        switch provider {
        case .qwen:
            let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
            let url = URL(string: "\(baseURL)/chat/completions")!
            var body: [String: Any] = [
                "model": resolvedModelId,
                "messages": [["role": "user", "content": prompt]],
                "temperature": 0.2
            ]
            if forceJSONResponse {
                body["response_format"] = ["type": "json_object"]
            }
            return try await sendChatCompletion(
                url: url,
                apiKey: trimmedKey,
                body: body,
                timeoutInterval: 45
            )

        case .deepseek:
            let baseURL = "https://api.deepseek.com"
            let url = URL(string: "\(baseURL)/chat/completions")!
            var body: [String: Any] = [
                "model": resolvedModelId,
                "messages": [["role": "user", "content": prompt]],
                "temperature": 0.2,
                "stream": false
            ]
            if forceJSONResponse {
                body["response_format"] = ["type": "json_object"]
            }
            return try await sendChatCompletion(
                url: url,
                apiKey: trimmedKey,
                body: body,
                timeoutInterval: 45
            )
        }
    }

    private func sendChatCompletion(
        url: URL,
        apiKey: String,
        body: [String: Any],
        timeoutInterval: TimeInterval = 15
    ) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let providerMessage = extractProviderErrorMessage(from: data)
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw AIServiceError.authenticationFailed
                }
                throw AIServiceError.providerError(statusCode: httpResponse.statusCode, message: providerMessage)
            }

            let content = try extractFirstMessageContent(from: data)
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw AIServiceError.invalidResponse }
            return trimmed
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw AIServiceError.timeout
            }
            logger.error("AI connection test network failed")
            throw AIServiceError.networkFailed(underlying: urlError)
        } catch let aiError as AIServiceError {
            throw aiError
        } catch {
            logger.error("AI connection test unknown error")
            throw AIServiceError.unknown(underlying: error)
        }
    }

    private func extractFirstMessageContent(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first else {
            throw AIServiceError.invalidResponse
        }

        // OpenAI-compatible: choices[].message.content
        if let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        // Fallback: sometimes content is directly in firstChoice
        if let content = firstChoice["text"] as? String {
            return content
        }

        throw AIServiceError.invalidResponse
    }

    private func extractProviderErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let errorObj = json["error"] as? [String: Any] {
            if let message = errorObj["message"] as? String { return message }
            if let type = errorObj["type"] as? String { return type }
        }

        if let message = json["message"] as? String { return message }
        return nil
    }
}

