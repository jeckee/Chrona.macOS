import Foundation

protocol AIServiceProtocol {
    func testConnection(provider: AIProvider, apiKey: String) async throws -> String
    func runChatCompletion(
        provider: AIProvider,
        apiKey: String,
        modelId: String,
        prompt: String,
        forceJSONResponse: Bool
    ) async throws -> String

    /// OpenAI-compatible streaming（SSE）的最小封装。
    /// - Returns: token/增量片段流（每次 yield 一个 content 片段）。
    func runChatCompletionStream(
        provider: AIProvider,
        apiKey: String,
        modelId: String,
        prompt: String
    ) throws -> AsyncThrowingStream<String, Error>
}

