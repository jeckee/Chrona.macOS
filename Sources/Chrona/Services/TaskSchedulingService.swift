import Foundation

final class TaskSchedulingService: TaskSchedulingServiceProtocol {
    private let aiService: AIServiceProtocol

    init(aiService: AIServiceProtocol = AIService.shared) {
        self.aiService = aiService
    }

    func schedule(
        request: SchedulingServiceRequest,
        provider: AIProvider,
        apiKey: String,
        modelId: String
    ) async throws -> SchedulingLLMResponse {
        let prompt = try SchedulingPromptBuilder.buildPrompt(from: request)
        print("========== SCHEDULING PROMPT ==========")
        print(prompt)
        print("=======================================")
        let raw = try await aiService.runChatCompletion(
            provider: provider,
            apiKey: apiKey,
            modelId: modelId,
            prompt: prompt,
            forceJSONResponse: true
        )
        let jsonData = try extractJSONData(from: raw)
        let decoded = try decodeResponse(jsonData)
        try validate(decoded, against: request)
        return decoded
    }

    private func extractJSONData(from raw: String) throws -> Data {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}") else {
            throw TaskSchedulingServiceError.responseJSONNotFound
        }
        let candidate = String(trimmed[start...end])
        guard let data = candidate.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw TaskSchedulingServiceError.responseJSONNotFound
        }
        return data
    }

    private func decodeResponse(_ data: Data) throws -> SchedulingLLMResponse {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(SchedulingLLMResponse.self, from: data)
        } catch {
            throw TaskSchedulingServiceError.invalidResponseSchema
        }
    }

    private func validate(_ response: SchedulingLLMResponse, against request: SchedulingServiceRequest) throws {
        let allTaskIds = Set(request.scheduledTasks.map(\.taskId) + request.unscheduledTasks.map(\.taskId))
        let unscheduledTaskIds = Set(request.unscheduledTasks.map(\.taskId))
        let allowedPriority = Set(["low", "medium", "high"])

        for update in response.taskUpdates {
            guard unscheduledTaskIds.contains(update.taskId) else {
                throw TaskSchedulingServiceError.invalidTaskId(update.taskId)
            }
            guard update.estimatedMinutes > 0 else {
                throw TaskSchedulingServiceError.invalidResponseSchema
            }
            guard allowedPriority.contains(update.priority) else {
                throw TaskSchedulingServiceError.invalidTaskPriority(update.priority)
            }
        }

        for item in response.scheduleResult.scheduled {
            guard allTaskIds.contains(item.taskId) else {
                throw TaskSchedulingServiceError.invalidTaskId(item.taskId)
            }
            let start = item.start
            let end = item.end
            guard !start.isEmpty, !end.isEmpty else {
                throw TaskSchedulingServiceError.invalidResponseSchema
            }
            // 不再检查是否严格前缀匹配 selectedDate，因为允许跨天或超出当天的排期
        }

        for item in response.scheduleResult.unscheduled {
            guard allTaskIds.contains(item.taskId) else {
                throw TaskSchedulingServiceError.invalidTaskId(item.taskId)
            }
            guard !item.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TaskSchedulingServiceError.invalidResponseSchema
            }
        }
    }
}
