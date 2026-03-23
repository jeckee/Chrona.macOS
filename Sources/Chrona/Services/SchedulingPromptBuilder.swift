import Foundation

enum SchedulingPromptBuilder {
    static func buildPrompt(from request: SchedulingServiceRequest) throws -> String {
        guard !request.selectedDate.isEmpty else {
            throw TaskSchedulingServiceError.invalidPromptInput
        }

        let selectedDate = request.selectedDate
        let workingHours = try jsonString(request.workingHours)
        let scheduledTasks = try jsonString(request.scheduledTasks)
        let unscheduledTasks = try jsonString(request.unscheduledTasks)

        return """
你是一个工作日任务排期助手。你的任务是为“当前选中日期”的任务生成一个尽可能可执行的日程安排。

# 你的目标
请基于输入数据，一次性完成两件事：

1. 为当前日期下的 UNSCHEDULED 任务补全关键字段：
- estimatedMinutes：预估时长（单位：分钟）
- priority：任务优先级，只能是 low / medium / high
- 仅对 `needs_analysis = true` 的任务做补全；`needs_analysis = false` 代表该任务已分析过，不要重复分析

2. 基于：
- 当前工作时间段
- 已有的 SCHEDULED 任务
- 刚补全信息的 UNSCHEDULED 任务
生成新的排期建议。

# 排期原则
请严格遵守以下原则：

1. 当前已有的 SCHEDULED 任务优先保留，不要轻易修改。
2. 尽可能不改变已有 SCHEDULED 任务的前后顺序。
3. 如果已有 SCHEDULED 任务的时间本身已经合理，尽量保持原开始结束时间不变。
4. UNSCHEDULED 任务需要根据任务内容推断合理时长和优先级。
5. 如果任务文本里包含明确时间信息，例如“14:00-15:00开会”，请把它视为强时间约束。
6. 优先安排 high，再安排 medium，再安排 low。
7. 如果当天工作时间不足，不要强行排满。可以保留部分任务为未排期。
8. 生成的排期必须落在工作时间段内。
9. 不要输出跨天排期。
10. 不要输出重叠的时间块。
11. 如果某个任务明显不适合今天完成，也可以保留在未排期中，并说明原因。

# 关于任务标题
1. 尽量保留用户原始任务标题。
2. 不要大幅改写 title。
3. 如有必要，只做轻微清洗，例如去掉多余空格，但不要改变任务本意。

# priority 规则
只能输出以下三个值之一：
- low
- medium
- high

可参考以下理解：
- high：有明确时效性、重要性高、今天更应该推进
- medium：普通正常任务
- low：可以延后，今天不做影响较小

# estimatedMinutes 规则
1. 必须输出整数分钟数。
2. 尽量给出合理值，例如 15 / 30 / 45 / 60 / 90 / 120。
3. 如果任务中已有明确时长信息，例如“开会2小时”，请优先使用该信息。
4. 如果任务中已有明确时间段，例如“14:00-15:00”，则时长应与时间段一致。

# 输出要求
你必须只输出 JSON，不要输出任何额外解释，不要输出 markdown，不要输出代码块。

输出 JSON 结构必须严格符合以下格式：

{
  "task_updates": [
    {
      "taskId": "string",
      "title": "string",
      "estimatedMinutes": 30,
      "priority": "medium",
      "timeHint": "string or empty",
      "ai_suggestions": ["string"]
    }
  ],
  "schedule_result": {
    "scheduled": [
      {
        "taskId": "string",
        "start": "YYYY-MM-DDTHH:MM:SS",
        "end": "YYYY-MM-DDTHH:MM:SS"
      }
    ],
    "unscheduled": [
      {
        "taskId": "string",
        "reason": "string"
      }
    ]
  }
}

# 字段说明
1. task_updates：
- 只需要为输入中 `needs_analysis = true` 的 UNSCHEDULED 任务输出
- title 尽量保留原始标题
- timeHint 用于提取任务中显式或隐式的时间提示，没有则输出空字符串
- ai_suggestions：给出 1~3 条简短、可执行的行动建议（字符串数组）；无建议则输出空数组

2. schedule_result.scheduled：
- 应包含最终建议排入日程的所有任务
- 包括原本已有的 SCHEDULED 任务
- 以及这次新安排进去的任务
- 时间必须是完整 ISO 格式
- 不允许时间重叠
- 不允许超出工作时间段

3. schedule_result.unscheduled：
- 放当天无法合理安排的任务
- reason 要简短明确，例如：
  - "not enough time"
  - "low priority"
  - "conflicts with fixed-time tasks"

# 输入数据
当前选中日期：
\(selectedDate)

工作时间段：
\(workingHours)

当前已有 SCHEDULED 任务：
\(scheduledTasks)

当前 UNSCHEDULED 任务：
\(unscheduledTasks)

# 额外约束
1. 如果某个任务已经在 SCHEDULED 中，请尽量保留它。
2. 如果某个 UNSCHEDULED 任务包含固定时间约束，应优先围绕该时间约束安排。
3. 如果一个任务明显是会议、值守、固定时间事项，优先视为强约束任务。
4. 如果某个任务信息不足，请根据常识给出保守估计。
5. 输出必须是合法 JSON。
6. 对于 `needs_analysis = false` 的任务，不要返回该任务的 task_updates。
"""
    }

    private static func jsonString<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw TaskSchedulingServiceError.invalidPromptInput
        }
        return json
    }
}
