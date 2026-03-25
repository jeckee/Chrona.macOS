import Foundation

enum SummaryPromptBuilder {
    struct SummaryTaskInput: Encodable {
        let taskId: String
        let title: String
        let status: String
        let isScheduled: Bool
        let priority: String
        let estimatedMinutes: Int?
        let conclusion: String

        init(task: ChronaTask) {
            self.taskId = task.id.uuidString
            self.title = task.title
            self.status = task.status.rawValue
            self.isScheduled = task.isScheduled
            self.priority = task.priority.rawValue
            self.estimatedMinutes = task.estimatedMinutes
            self.conclusion = task.conclusion ?? ""
        }
    }

    static func buildPrompt(date: Date, tasks: [ChronaTask]) throws -> String {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let dateText = Self.isoDateOnlyFormatter.string(from: normalizedDate)

        let inputTasks = tasks.map(SummaryTaskInput.init)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let inputData = try encoder.encode(inputTasks)
        guard let tasksJson = String(data: inputData, encoding: .utf8) else {
            throw TaskSchedulingServiceError.invalidPromptInput
        }

        // 注意：输出要求为纯文本（不要求 JSON），但结构必须固定为五部分标题。
        return """
你是一个工作助手。请基于输入数据，为指定日期生成“当日总结”。必须严格遵守规则：只依据输入，不要编造事实或细节。

日期：\(dateText)

# 你的输出结构（固定为 5 部分，按顺序输出）
1. 今日完成
2. 今日未完成
3. 关键进展
4. 风险 / 阻塞
5. 明日建议

# 分类规则
- status 为 `done` 的任务归入「今日完成」，其他（`todo` / `inProgress` / `paused`）归入「今日未完成」。
- 每个任务标题与其 status 可以用于辅助组织，但不要编造该任务在输入之外的事实。
- conclusion 为空字符串（或不存在）时：仍然把任务按状态归入完成/未完成；但不要从空 conclusion 推断具体进展或阻塞。

# 关键内容提炼
- 「关键进展」：优先从 conclusion 中提炼“做了什么/推进到哪里”的信息；若所有 conclusion 都为空，则基于未完成任务的标题与状态给出简短的推进方向（避免具体细节编造）。
- 「风险 / 阻塞」：当 conclusion 中出现问题、卡住、待继续、需要协作等语义时归纳到该部分。
- 「明日建议」：尽量基于「今日未完成」与「风险 / 阻塞」提出明日的下一步建议，保持简洁可执行。

# 风格要求
- 语言：与输入一致（中文）。
- 简洁清晰，偏工作总结风格。
- 不要输出 JSON，不要输出代码块，不要输出额外解释。
- 每部分控制在 3~6 条要点，允许用换行分隔要点。

# 输入数据（JSON 数组，每项为一个任务）
[\(tasksJson)]
"""
    }

    private static let isoDateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

