import Foundation

/// 仅支持两种模型提供方：Qwen / DeepSeek
enum AIProvider: String, Codable, CaseIterable, Identifiable, Hashable {
    case qwen
    case deepseek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen: return "Qwen"
        case .deepseek: return "DeepSeek"
        }
    }

    /// 本轮仅支持单一默认模型；后续如要扩展多模型菜单，可在此演进。
    var defaultModelId: String {
        switch self {
        case .qwen:
            // 按需求：Qwen 默认使用 qwen3.5 plus
            return "qwen3.5-plus"
        case .deepseek:
            return "deepseek-chat"
        }
    }

    /// UI 侧的模型菜单：本轮仅返回一个默认项。
    var models: [String] { [defaultModelId] }

    /// 向后兼容旧版 `selectedProviderId`（显示名字符串）。
    static func fromLegacyProviderId(_ legacy: String) -> AIProvider? {
        switch legacy {
        case "Alibaba DashScope (Qwen)":
            return .qwen
        default:
            return nil
        }
    }
}

