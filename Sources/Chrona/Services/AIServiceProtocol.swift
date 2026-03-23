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
}

