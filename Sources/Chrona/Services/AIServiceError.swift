import Foundation

enum AIServiceError: Error {
    case apiKeyEmpty
    case providerNotSelected

    case networkFailed(underlying: Error)
    case timeout

    case authenticationFailed
    case providerError(statusCode: Int, message: String?)

    case invalidResponse
    case unknown(underlying: Error?)

    var userMessage: String {
        switch self {
        case .apiKeyEmpty:
            return "API Key 为空，请先在设置中填写。"
        case .providerNotSelected:
            return "未选择 AI Provider。"
        case .networkFailed:
            return "网络请求失败，请检查网络后重试。"
        case .timeout:
            return "请求超时，请稍后重试。"
        case .authenticationFailed:
            return "鉴权失败：API Key 无效或权限不足。"
        case .providerError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Provider 返回错误（HTTP \(statusCode)）：\(message)"
            } else {
                return "Provider 返回错误（HTTP \(statusCode)）。"
            }
        case .invalidResponse:
            return "Provider 返回了无效响应，无法解析。"
        case .unknown:
            return "未知错误，请稍后重试。"
        }
    }
}

extension AIServiceError: LocalizedError {
    var errorDescription: String? { userMessage }
}

