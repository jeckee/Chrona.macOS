import Foundation

final class SummaryService: SummaryServiceProtocol {
    private let aiService: AIServiceProtocol

    init(aiService: AIServiceProtocol = AIService.shared) {
        self.aiService = aiService
    }

    func generateSummaryStream(
        date: Date,
        tasks: [ChronaTask],
        provider: AIProvider,
        apiKey: String,
        modelId: String
    ) throws -> AsyncThrowingStream<String, Error> {
        let prompt = try SummaryPromptBuilder.buildPrompt(date: date, tasks: tasks)
        return try aiService.runChatCompletionStream(
            provider: provider,
            apiKey: apiKey,
            modelId: modelId,
            prompt: prompt
        )
    }
}

