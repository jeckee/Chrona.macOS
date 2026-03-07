import Foundation
import os

// MARK: - Qwen API Service
class QwenAPIService {
    static let shared = QwenAPIService()

    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    private let model = "qwen3-max"
    private let logger = Logger(subsystem: "com.chrona.app", category: "LLM")

    private init() {}

    // MARK: - Generate Plan
    /// - Parameters:
    ///   - existingPlan: 今日已有计划（非空时表示在现有计划基础上插入/合并新内容）
    ///   - carryOverTitles: 昨日未完成的任务标题列表（新的一天时传入，用于重新安排）
    func generatePlan(
        date: Date,
        workingBlocks: [WorkingBlock],
        userInput: String,
        existingPlan: DayPlan? = nil,
        carryOverTitles: [String] = []
    ) async throws -> GeneratePlanResponse {
        let logDateStr = Self.logDateFormatter.string(from: date)
        logger.info("[generatePlan] 开始 date=\(logDateStr, privacy: .public) workingBlocks=\(workingBlocks.count, privacy: .public) existingPlan=\(existingPlan != nil, privacy: .public) carryOver=\(carryOverTitles.count, privacy: .public)")

        let apiKey = SettingsManager.shared.qwenAPIKey
        guard !apiKey.isEmpty else {
            logger.error("[generatePlan] 失败: 未配置 API Key")
            throw APIError.missingAPIKey
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        // 计算剩余可用工作时间段
        let now = Date()
        var validBlocks: [String] = []
        
        for block in workingBlocks {
            guard let range = block.toDateRange(on: date) else { continue }
            
            if range.end <= now {
                // 时间段已过，忽略
                continue
            } else if range.start <= now {
                // 当前时间在此时间段内，从当前时间开始
                let startStr = timeFormatter.string(from: now)
                validBlocks.append("\(startStr)-\(block.end)")
            } else {
                // 将来的时间段，保持原样
                validBlocks.append("\(block.start)-\(block.end)")
            }
        }
        
        let workingBlocksStr = validBlocks.isEmpty ? "无剩余工作时间" : validBlocks.joined(separator: ", ")

        var contextSection = ""
        if let existing = existingPlan, !existing.planItems.isEmpty {
            let itemsDesc = existing.planItems.map { item in
                "  - task_id: \(item.taskId.uuidString), \(timeFormatter.string(from: item.start))~\(timeFormatter.string(from: item.end)) \(item.title)"
            }.joined(separator: "\n")
            contextSection = """
            **当前今日已有计划**（请保留这些项并沿用其 task_id，在空档或合理位置插入用户新描述的任务，输出合并后的完整 plan_items）:
            \(itemsDesc)

            """
        } else if !carryOverTitles.isEmpty {
            let carryStr = carryOverTitles.map { "  - \($0)" }.joined(separator: "\n")
            contextSection = """
            **昨日未完成的任务**（请在今日工作时间内重新安排这些任务）:
            \(carryStr)

            """
        }

        let inputSection = userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (existingPlan != nil ? "（用户未填写新内容，仅做微调或保持现有计划）" : "（用户未填写，请根据工作日场景自行建议今日计划，例如：晨间复盘、重点任务、会议、休息等）")
            : userInput

        let prompt = """
        你是一个智能时间管理助手。请根据上下文和用户描述生成今日计划。

        **今日日期**: \(dateString)
        **剩余可用工作时间段**: \(workingBlocksStr)
        \(contextSection)**用户今日描述（可选）**: \(inputSection)

        **要求**:
        1. 请严格根据「剩余可用工作时间段」来安排任务。
        2. 若有「当前今日已有计划」，必须保留其中每一项（时间可微调避免重叠），再插入用户新描述的任务，输出合并后的完整 plan_items；每个已有项请保留原 task_id（若无法获知则生成新 UUID），新项生成新 UUID
        3. 若有「昨日未完成的任务」，在今日工作时间内为它们安排时间，并可为用户描述的新目标预留空间；每项生成新 UUID
        4. 若无上述上下文，则根据用户描述或工作日场景直接生成今日计划项
        5. 每项包含 title、start(HH:mm)、end(HH:mm)、locked(默认 false)、tips(2-3 条)
        6. 所有计划项必须安排在工作时间段内，且时间不得重叠
        7. 无法安排的内容放入 overflow_tasks，填写 task_id、title、reason、suggestion

        **输出格式**（必须是有效的 JSON）:
        {
          "plan_items": [
            {
              "task_id": "UUID字符串",
              "title": "任务标题",
              "start": "HH:mm",
              "end": "HH:mm",
              "locked": false,
              "tips": ["提示1", "提示2"]
            }
          ],
          "overflow_tasks": [
            {
              "task_id": "UUID字符串",
              "title": "未安排项标题",
              "reason": "无法安排的原因",
              "suggestion": "建议"
            }
          ]
        }
        """

        let response = try await callAPI(prompt: prompt, apiKey: apiKey, operation: "generatePlan")

        // 解析 JSON 响应（兼容被包在说明文字或 ```json 代码块中的情况）
        guard let jsonString = Self.extractJSONString(from: response),
              let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let planItemsArray = json["plan_items"] as? [[String: Any]] else {
            logger.error("[generatePlan] 响应解析失败，原始长度=\(response.count, privacy: .public)")
            throw APIError.invalidResponse
        }

        var planItems: [PlanItem] = []
        for itemDict in planItemsArray {
            guard let taskIdStr = itemDict["task_id"] as? String,
                  let taskId = UUID(uuidString: taskIdStr),
                  let title = itemDict["title"] as? String,
                  let startStr = itemDict["start"] as? String,
                  let endStr = itemDict["end"] as? String else {
                continue
            }

            let locked = itemDict["locked"] as? Bool ?? false
            let tips = itemDict["tips"] as? [String] ?? []

            // 解析时间
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            guard let startTime = timeFormatter.date(from: startStr),
                  let endTime = timeFormatter.date(from: endStr) else {
                continue
            }

            let calendar = Calendar.current
            guard let start = calendar.date(bySettingHour: calendar.component(.hour, from: startTime),
                                           minute: calendar.component(.minute, from: startTime),
                                           second: 0, of: date),
                  let end = calendar.date(bySettingHour: calendar.component(.hour, from: endTime),
                                         minute: calendar.component(.minute, from: endTime),
                                         second: 0, of: date) else {
                continue
            }

            planItems.append(PlanItem(taskId: taskId, title: title, start: start, end: end, locked: locked, tips: tips))
        }

        var overflowTasks: [OverflowTask] = []
        if let overflowArray = json["overflow_tasks"] as? [[String: Any]] {
            for itemDict in overflowArray {
                guard let taskIdStr = itemDict["task_id"] as? String,
                      let taskId = UUID(uuidString: taskIdStr),
                      let reason = itemDict["reason"] as? String,
                      let suggestion = itemDict["suggestion"] as? String else {
                    continue
                }
                let title = itemDict["title"] as? String
                overflowTasks.append(OverflowTask(taskId: taskId, title: title, reason: reason, suggestion: suggestion))
            }
        }

        logger.info("[generatePlan] 成功 planItems=\(planItems.count, privacy: .public) overflowTasks=\(overflowTasks.count, privacy: .public)")
        return GeneratePlanResponse(planItems: planItems, overflowTasks: overflowTasks)
    }

    // MARK: - Generate Summary
    func generateSummary(date: Date, planItems: [PlanItem], tasks: [Task]) async throws -> String {
        let logDateStr = Self.logDateFormatter.string(from: date)
        logger.info("[generateSummary] 开始 date=\(logDateStr, privacy: .public) planItems=\(planItems.count, privacy: .public) tasks=\(tasks.count, privacy: .public)")

        let apiKey = SettingsManager.shared.qwenAPIKey
        guard !apiKey.isEmpty else {
            logger.error("[generateSummary] 失败: 未配置 API Key")
            throw APIError.missingAPIKey
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let completedTasks = tasks.filter { $0.status == .done }
        let uncompletedTasks = tasks.filter { $0.status == .todo }

        let completedStr = completedTasks.map { "- \($0.title)" }.joined(separator: "\n")
        let uncompletedStr = uncompletedTasks.map { "- \($0.title)" }.joined(separator: "\n")

        let prompt = """
        你是一个智能时间管理助手。请为用户生成今日工作总结。

        **今日日期**: \(dateString)
        **已完成任务**:
        \(completedStr.isEmpty ? "无" : completedStr)

        **未完成任务**:
        \(uncompletedStr.isEmpty ? "无" : uncompletedStr)

        **要求**:
        1. 生成简短的每日总结（2-3 句话）
        2. 突出完成情况和主要成果
        3. 如有未完成任务，给出简要建议

        请直接输出总结文本，不需要 JSON 格式。
        """

        let response = try await callAPI(prompt: prompt, apiKey: apiKey, operation: "generateSummary")
        let summary = response.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("[generateSummary] 成功 总结长度=\(summary.count, privacy: .public)")
        return summary
    }

    // MARK: - API Call
    private func callAPI(prompt: String, apiKey: String, operation: String = "callAPI") async throws -> String {
        logger.debug("[LLM] \(operation, privacy: .public) 请求 model=\(self.model, privacy: .public) promptLength=\(prompt.count, privacy: .public)")

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("[LLM] \(operation) 网络错误: 非 HTTP 响应")
            throw APIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("[LLM] \(operation, privacy: .public) HTTP 错误 statusCode=\(httpResponse.statusCode, privacy: .public) bodyPreview=\(String(data: data.prefix(200), encoding: .utf8) ?? "", privacy: .public)")
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            logger.error("[LLM] \(operation, privacy: .public) 响应格式无效 dataLength=\(data.count, privacy: .public)")
            throw APIError.invalidResponse
        }

        // Qwen 兼容模式通常直接返回字符串，但也有可能是富文本结构，这里做一次兼容处理
        if let content = message["content"] as? String {
            logger.debug("[LLM] \(operation, privacy: .public) 响应成功 contentLength=\(content.count, privacy: .public)")
            return content
        }

        // 兼容 content 为数组的情况，例如 [{ "type": "text", "text": { "value": "..." } }]
        if let contentArray = message["content"] as? [[String: Any]] {
            for item in contentArray {
                if let type = item["type"] as? String, type == "text",
                   let text = item["text"] as? [String: Any],
                   let value = text["value"] as? String {
                    logger.debug("[LLM] \(operation, privacy: .public) 响应成功 contentLength=\(value.count, privacy: .public)")
                    return value
                }
                if let plain = item["text"] as? String {
                    logger.debug("[LLM] \(operation, privacy: .public) 响应成功 contentLength=\(plain.count, privacy: .public)")
                    return plain
                }
            }
        }

        logger.error("[LLM] \(operation, privacy: .public) 无法从 message 中解析 content")
        throw APIError.invalidResponse
    }

    // MARK: - Helpers
    private static let logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 从模型返回的完整文本中提取 JSON 子串，容忍前后有解释文字或 ```json 包裹
    private static func extractJSONString(from text: String) -> String? {
        // 先粗暴地截取第一个 { 到 最后一个 } 之间的内容
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}") else {
            return nil
        }
        let range = firstBrace...lastBrace
        let candidate = String(text[range])
        return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - API Models
struct GeneratePlanResponse {
    let planItems: [PlanItem]
    let overflowTasks: [OverflowTask]
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case missingAPIKey
    case networkError
    case httpError(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未配置 Qwen API Key，请在设置中配置"
        case .networkError:
            return "网络错误"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .invalidResponse:
            return "无效的响应格式"
        }
    }
}
