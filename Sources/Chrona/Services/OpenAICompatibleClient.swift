import Foundation
import os

/// OpenAI 兼容 Chat Completions（Bearer + `/v1/chat/completions`）。OpenAI / OpenRouter / DeepSeek 复用。
struct OpenAICompatibleClient: AIClientProtocol {
    let baseURL: String
    let defaultModelId: String
    let session: URLSession
    let extraHeaders: [String: String]

    private let logger = Logger(subsystem: "com.chrona.app", category: "OpenAICompatible")

    init(
        baseURL: String,
        defaultModelId: String,
        session: URLSession = .shared,
        extraHeaders: [String: String] = [:]
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.defaultModelId = defaultModelId
        self.session = session
        self.extraHeaders = extraHeaders
    }

    func testConnection(apiKey: String) async throws -> String {
        let model = defaultModelId
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "Reply with OK only."]],
            "temperature": 0,
            "max_tokens": 16,
            "stream": false,
        ]
        return try await postChatCompletion(apiKey: apiKey, body: body, timeout: 30)
    }

    func generateText(apiKey: String, modelId: String, prompt: String, forceJSONResponse: Bool) async throws -> String {
        let model = resolvedModel(modelId)
        var body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.2,
            "stream": false,
        ]
        if forceJSONResponse {
            body["response_format"] = ["type": "json_object"]
        }
        return try await postChatCompletion(apiKey: apiKey, body: body, timeout: 120)
    }

    func streamText(apiKey: String, modelId: String, prompt: String) throws -> AsyncThrowingStream<String, Error> {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let model = resolvedModel(modelId)
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.2,
            "max_tokens": 800,
            "stream": true,
        ]

        let url = URL(string: "\(baseURL)/chat/completions")!

        return AsyncThrowingStream { continuation in
            let streamTask = Task {
                do {
                    var request = URLRequest(url: url, timeoutInterval: 180)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
                    for (k, v) in extraHeaders {
                        request.setValue(v, forHTTPHeaderField: k)
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (byteStream, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    guard httpResponse.statusCode == 200 else {
                        throw AIServiceError.providerError(statusCode: httpResponse.statusCode, message: nil)
                    }

                    for try await line in byteStream.lines {
                        if Task.isCancelled { break }
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }

                        let dataPart = trimmed
                            .dropFirst("data:".count)
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        if dataPart == "[DONE]" { break }

                        guard let data = dataPart.data(using: .utf8) else { continue }
                        guard
                            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                            let choices = json["choices"] as? [[String: Any]],
                            let firstChoice = choices.first
                        else { continue }

                        if let delta = firstChoice["delta"] as? [String: Any],
                           let content = delta["content"] as? String,
                           !content.isEmpty {
                            continuation.yield(content)
                        } else if let text = firstChoice["text"] as? String,
                                  !text.isEmpty {
                            continuation.yield(text)
                        }
                    }

                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    continuation.finish()
                } catch let urlError as URLError {
                    if urlError.code == .timedOut {
                        continuation.finish(throwing: AIServiceError.timeout)
                    } else {
                        continuation.finish(throwing: AIServiceError.networkFailed(underlying: urlError))
                    }
                } catch let aiError as AIServiceError {
                    continuation.finish(throwing: aiError)
                } catch {
                    logger.error("OpenAI-compatible stream failed")
                    continuation.finish(throwing: AIServiceError.unknown(underlying: error))
                }
            }

            continuation.onTermination = { @Sendable _ in
                streamTask.cancel()
            }
        }
    }

    private func resolvedModel(_ modelId: String) -> String {
        let t = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? defaultModelId : t
    }

    private func postChatCompletion(apiKey: String, body: [String: Any], timeout: TimeInterval) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        for (k, v) in extraHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let providerMessage = Self.extractOpenAIStyleError(from: data)
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw AIServiceError.authenticationFailed
                }
                throw AIServiceError.providerError(statusCode: httpResponse.statusCode, message: providerMessage)
            }

            let content = try Self.extractFirstMessageContent(from: data)
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw AIServiceError.invalidResponse }
            return trimmed
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw AIServiceError.timeout
            }
            throw AIServiceError.networkFailed(underlying: urlError)
        } catch let aiError as AIServiceError {
            throw aiError
        } catch {
            throw AIServiceError.unknown(underlying: error)
        }
    }

    private static func extractFirstMessageContent(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first else {
            throw AIServiceError.invalidResponse
        }

        if let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        if let content = firstChoice["text"] as? String {
            return content
        }

        throw AIServiceError.invalidResponse
    }

    private static func extractOpenAIStyleError(from data: Data) -> String? {
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
