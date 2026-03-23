import Foundation

struct SchedulingServiceRequest {
    struct WorkingHour: Encodable {
        let start: String
        let end: String
    }

    struct ScheduledTask: Encodable {
        let taskId: String
        let title: String
        let start: String
        let end: String
    }

    struct UnscheduledTask: Encodable {
        let taskId: String
        let title: String
        let estimatedMinutes: Int?
        let priority: String?
        let userTimeHint: String?
        let needsAnalysis: Bool

        private enum CodingKeys: String, CodingKey {
            case taskId
            case title
            case estimatedMinutes
            case priority
            case userTimeHint
            case needsAnalysis = "needs_analysis"
        }
    }

    let selectedDate: String
    let workingHours: [WorkingHour]
    let scheduledTasks: [ScheduledTask]
    let unscheduledTasks: [UnscheduledTask]
}

struct SchedulingLLMResponse: Decodable {
    struct TaskUpdate: Decodable {
        let taskId: String
        let title: String
        let estimatedMinutes: Int
        let priority: String
        let timeHint: String
        let aiSuggestions: [String]

        private enum CodingKeys: String, CodingKey {
            case taskId
            case title
            case estimatedMinutes
            case priority
            case timeHint
            case aiSuggestions = "ai_suggestions"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            taskId = try c.decode(String.self, forKey: .taskId)
            title = try c.decode(String.self, forKey: .title)
            estimatedMinutes = try c.decode(Int.self, forKey: .estimatedMinutes)
            priority = try c.decode(String.self, forKey: .priority)
            timeHint = (try? c.decode(String.self, forKey: .timeHint)) ?? ""
            aiSuggestions = (try? c.decode([String].self, forKey: .aiSuggestions)) ?? []
        }
    }

    struct ScheduleResult: Decodable {
        struct ScheduledItem: Decodable {
            let taskId: String
            let start: String
            let end: String
        }

        struct UnscheduledItem: Decodable {
            let taskId: String
            let reason: String
        }

        let scheduled: [ScheduledItem]
        let unscheduled: [UnscheduledItem]
    }

    let taskUpdates: [TaskUpdate]
    let scheduleResult: ScheduleResult

    private enum CodingKeys: String, CodingKey {
        case taskUpdates = "task_updates"
        case scheduleResult = "schedule_result"
    }
}

enum TaskSchedulingServiceError: LocalizedError {
    case invalidPromptInput
    case responseJSONNotFound
    case invalidResponseSchema
    case invalidTaskPriority(String)
    case invalidTaskId(String)
    case invalidScheduleDate(String)

    var errorDescription: String? {
        switch self {
        case .invalidPromptInput:
            return "排期输入数据不完整。"
        case .responseJSONNotFound:
            return "模型返回内容不是合法 JSON。"
        case .invalidResponseSchema:
            return "模型返回 JSON 字段不完整或格式错误。"
        case .invalidTaskPriority(let value):
            return "模型返回了不支持的 priority 值：\(value)"
        case .invalidTaskId(let value):
            return "模型返回了未知 taskId：\(value)"
        case .invalidScheduleDate(let value):
            return "模型返回了非法时间：\(value)"
        }
    }
}
