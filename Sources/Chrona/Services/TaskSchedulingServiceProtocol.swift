import Foundation

protocol TaskSchedulingServiceProtocol {
    func schedule(
        request: SchedulingServiceRequest,
        provider: AIProvider,
        apiKey: String,
        modelId: String
    ) async throws -> SchedulingLLMResponse
}
