import Foundation
import os

/// Google Gemini（Generative Language API，API Key 走 query `key=`）。
enum GoogleClient {
    static let shared: AIClientProtocol = GoogleClientImpl()
}

private struct GoogleClientImpl: AIClientProtocol {
    private let session: URLSession = .shared
    private let logger = Logger(subsystem: "com.chrona.app", category: "GoogleGemini")
    private let defaultModel = "gemini-2.0-flash"
    private let base = "https://generativelanguage.googleapis.com/v1beta/models"

    func testConnection(apiKey: String) async throws -> String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let model = defaultModel
        let url = try makeURL(model: model, method: "generateContent", apiKey: trimmed)
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": "Reply with OK only."]]],
            ],
            "generationConfig": [
                "temperature": 0,
                "maxOutputTokens": 16,
            ],
        ]
        return try await post(url: url, body: body, timeout: 30)
    }

    func generateText(apiKey: String, modelId: String, prompt: String, forceJSONResponse: Bool) async throws -> String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let model = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : modelId
        let url = try makeURL(model: model, method: "generateContent", apiKey: trimmed)
        var genConfig: [String: Any] = [
            "temperature": 0.2,
        ]
        if forceJSONResponse {
            genConfig["responseMimeType"] = "application/json"
        }
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": prompt]]],
            ],
            "generationConfig": genConfig,
        ]
        return try await post(url: url, body: body, timeout: 120)
    }

    func streamText(apiKey: String, modelId: String, prompt: String) throws -> AsyncThrowingStream<String, Error> {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIServiceError.apiKeyEmpty }

        let model = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : modelId
        let url: URL
        do {
            url = try makeURL(model: model, method: "streamGenerateContent", apiKey: trimmed, altSse: true)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": prompt]]],
            ],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 800,
            ],
        ]

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url, timeoutInterval: 180)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
                        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard t.hasPrefix("data:") else { continue }
                        let dataPart = t.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                        guard let data = dataPart.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        if let text = Self.extractStreamedText(from: json), !text.isEmpty {
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
                    logger.error("Gemini stream failed")
                    continuation.finish(throwing: AIServiceError.unknown(underlying: error))
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    private func makeURL(model: String, method: String, apiKey: String, altSse: Bool = false) throws -> URL {
        var comp = URLComponents(string: "\(base)/\(model):\(method)")!
        var items = [URLQueryItem(name: "key", value: apiKey)]
        if altSse {
            items.append(URLQueryItem(name: "alt", value: "sse"))
        }
        comp.queryItems = items
        guard let url = comp.url else {
            throw AIServiceError.invalidResponse
        }
        return url
    }

    private func post(url: URL, body: [String: Any], timeout: TimeInterval) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            if http.statusCode != 200 {
                let msg = Self.extractGeminiError(from: data)
                if http.statusCode == 401 || http.statusCode == 403 {
                    throw AIServiceError.authenticationFailed
                }
                throw AIServiceError.providerError(statusCode: http.statusCode, message: msg)
            }
            let text = try Self.extractCandidateText(from: data)
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

    private static func extractCandidateText(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw AIServiceError.invalidResponse
        }
        var chunks: [String] = []
        for p in parts {
            if let t = p["text"] as? String { chunks.append(t) }
        }
        guard !chunks.isEmpty else { throw AIServiceError.invalidResponse }
        return chunks.joined()
    }

    private static func extractStreamedText(from json: [String: Any]) -> String? {
        guard let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            return nil
        }
        var out = ""
        for p in parts {
            if let t = p["text"] as? String { out += t }
        }
        return out.isEmpty ? nil : out
    }

    private static func extractGeminiError(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = json["error"] as? [String: Any] {
            return (err["message"] as? String) ?? (err["status"] as? String)
        }
        return nil
    }
}
