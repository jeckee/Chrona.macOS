import Foundation

enum OpenAIClient {
    static let shared: AIClientProtocol = OpenAICompatibleClient(
        baseURL: "https://api.openai.com/v1",
        defaultModelId: "gpt-4o-mini"
    )
}
