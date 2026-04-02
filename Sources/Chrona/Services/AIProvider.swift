import Foundation

/// 支持的 AI 提供方（本轮固定 5 家，产品层相互独立）。
enum AIProvider: String, Codable, CaseIterable, Identifiable, Hashable {
    case openai
    case anthropic
    case google
    case openrouter
    case deepseek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        case .openrouter: return "OpenRouter"
        case .deepseek: return "DeepSeek"
        }
    }

    /// 每 Provider 单一默认模型；复杂模型列表不在本轮范围。
    var defaultModelId: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-haiku-20241022"
        case .google: return "gemini-2.0-flash"
        case .openrouter: return "openai/gpt-4o-mini"
        case .deepseek: return "deepseek-chat"
        }
    }

    var models: [String] { [defaultModelId] }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        if let p = AIProvider(rawValue: raw) {
            self = p
            return
        }
        // 旧版 rawValue / 遗留字符串
        switch raw {
        case "qwen": self = .openai
        case "deepseek": self = .deepseek
        case "Alibaba DashScope (Qwen)": self = .openai
        default:
            self = .openai
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}
