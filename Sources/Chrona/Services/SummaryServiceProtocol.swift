import Foundation

protocol SummaryServiceProtocol {
    func generateSummaryStream(
        date: Date,
        tasks: [ChronaTask],
        provider: AIProvider,
        apiKey: String,
        modelId: String
    ) throws -> AsyncThrowingStream<String, Error>
}

