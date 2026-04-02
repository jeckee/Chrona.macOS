import Foundation

final class AIService: AIServiceProtocol {
    static let shared = AIService()

    private init() {}

    func testConnection(provider: AIProvider, apiKey: String) async throws -> String {
        try await client(for: provider).testConnection(apiKey: apiKey)
    }

    func runChatCompletion(
        provider: AIProvider,
        apiKey: String,
        modelId: String,
        prompt: String,
        forceJSONResponse: Bool
    ) async throws -> String {
        try await client(for: provider).generateText(
            apiKey: apiKey,
            modelId: modelId,
            prompt: prompt,
            forceJSONResponse: forceJSONResponse
        )
    }

    func runChatCompletionStream(
        provider: AIProvider,
        apiKey: String,
        modelId: String,
        prompt: String
    ) throws -> AsyncThrowingStream<String, Error> {
        try client(for: provider).streamText(apiKey: apiKey, modelId: modelId, prompt: prompt)
    }

    private func client(for provider: AIProvider) -> AIClientProtocol {
        switch provider {
        case .openai: return OpenAIClient.shared
        case .anthropic: return AnthropicClient.shared
        case .google: return GoogleClient.shared
        case .openrouter: return OpenRouterClient.shared
        case .deepseek: return DeepSeekClient.shared
        }
    }
}
