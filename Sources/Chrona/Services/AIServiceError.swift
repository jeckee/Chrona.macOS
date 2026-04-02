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
            return "API key is empty. Add it in Settings first."
        case .providerNotSelected:
            return "No AI provider selected."
        case .networkFailed:
            return "Network request failed. Check your connection and try again."
        case .timeout:
            return "Request timed out. Try again later."
        case .authenticationFailed:
            return "Authentication failed: invalid API key or insufficient permissions."
        case .providerError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Provider error (HTTP \(statusCode)): \(message)"
            } else {
                return "Provider error (HTTP \(statusCode))."
            }
        case .invalidResponse:
            return "The provider returned a response that could not be parsed."
        case .unknown:
            return "Something went wrong. Try again later."
        }
    }
}

extension AIServiceError: LocalizedError {
    var errorDescription: String? { userMessage }
}

