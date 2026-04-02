import Foundation

enum DeepSeekClient {
    static let shared: AIClientProtocol = OpenAICompatibleClient(
        baseURL: "https://api.deepseek.com",
        defaultModelId: "deepseek-chat"
    )
}
