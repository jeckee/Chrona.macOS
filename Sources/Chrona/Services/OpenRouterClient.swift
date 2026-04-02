import Foundation

enum OpenRouterClient {
    /// OpenRouter 要求可识别的 Referer；使用占位 URL 满足常见校验。
    static let shared: AIClientProtocol = OpenAICompatibleClient(
        baseURL: "https://openrouter.ai/api/v1",
        defaultModelId: "openai/gpt-4o-mini",
        extraHeaders: [
            "HTTP-Referer": "https://chrona.app",
            "X-Title": "Chrona",
        ]
    )
}
