import Foundation

/// 各 Provider 的 HTTP 差异封装在 `AIClientProtocol` 实现中；Store / View 只通过 `AIService` 调用。
protocol AIClientProtocol: Sendable {
    /// 连接测试用极小请求。
    func testConnection(apiKey: String) async throws -> String

    /// 非流式补全（Schedule 等）。
    func generateText(apiKey: String, modelId: String, prompt: String, forceJSONResponse: Bool) async throws -> String

    /// 流式输出（Summary 等）。
    func streamText(apiKey: String, modelId: String, prompt: String) throws -> AsyncThrowingStream<String, Error>
}
