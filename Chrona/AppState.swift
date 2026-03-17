import Foundation
import SwiftUI

// MARK: - App State
class AppState: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var todayPlan: DayPlan?
    @Published var todaySummary: DaySummary?
    @Published var isGeneratingPlan = false
    @Published var isGeneratingSummary = false
    @Published var isGeneratingClues = false
    @Published var errorMessage: String?

    private var summaryTimer: Timer?

    init() {
        loadTasks()
        loadTodayPlan()
        loadTodaySummary()

        // 启动时重建提醒
        if let plan = todayPlan {
            NotificationManager.shared.cancelAllNotifications()
            NotificationManager.shared.scheduleNotifications(for: plan.planItems)
        }

        // 启动定时总结
        setupAutoSummary()
    }

    // MARK: - Tasks
    func loadTasks() {
        tasks = FileStorageManager.shared.loadTasks()
    }

    func saveTasks() {
        try? FileStorageManager.shared.saveTasks(tasks)
    }

    func addTask(raw: String) {
        let task = Task(raw: raw)
        tasks.append(task)
        saveTasks()
    }

    func addTasks(from text: String) {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            addTask(raw: line)
        }
    }

    func toggleTaskStatus(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = tasks[index].status == .todo ? .done : .todo
            saveTasks()
        }
    }

    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }

    /// 完成计划项：将对应任务标为已完成
    func completePlanItem(_ item: PlanItem) {
        if let index = tasks.firstIndex(where: { $0.id == item.taskId }) {
            tasks[index].status = .done
            saveTasks()
        }
    }

    /// 从今日计划中移除计划项，并删除对应任务
    func removePlanItemFromPlan(_ item: PlanItem) {
        if var plan = todayPlan {
            plan.planItems.removeAll { $0.id == item.id }
            todayPlan = plan
            saveTodayPlan()
        }
        tasks.removeAll { $0.id == item.taskId }
        saveTasks()
        NotificationManager.shared.cancelNotifications(for: [item])
    }

    /// 从今日计划中移除无法安排的任务，并删除对应任务
    func removeOverflowTask(_ overflow: OverflowTask) {
        if var plan = todayPlan {
            plan.overflowTasks.removeAll { $0.taskId == overflow.taskId }
            todayPlan = plan
            saveTodayPlan()
        }
        tasks.removeAll { $0.id == overflow.taskId }
        saveTasks()
    }

    /// 修改计划项时间，保存计划并重建提醒
    func updatePlanItemTime(item: PlanItem, newStart: Date, newEnd: Date) {
        guard newStart < newEnd else { return }
        guard var plan = todayPlan,
              let index = plan.planItems.firstIndex(where: { $0.id == item.id }) else { return }
        plan.planItems[index].start = newStart
        plan.planItems[index].end = newEnd
        todayPlan = plan
        saveTodayPlan()
        NotificationManager.shared.cancelAllNotifications()
        NotificationManager.shared.scheduleNotifications(for: plan.planItems)
    }

    /// 获取某任务的状态（用于计划项展示）
    func taskStatus(for taskId: UUID) -> Task.TaskStatus? {
        tasks.first(where: { $0.id == taskId })?.status
    }

    // MARK: - Plan
    func loadTodayPlan() {
        todayPlan = FileStorageManager.shared.loadDayPlan(for: Date())
    }

    func saveTodayPlan() {
        if let plan = todayPlan {
            try? FileStorageManager.shared.saveDayPlan(plan, for: Date())
        }
    }

    /// 根据当前顺序自动重新排布时间段（保持每个任务的时长不变）
    private func recalculatePlanTimes(for plan: inout DayPlan) {
        guard !plan.planItems.isEmpty else { return }

        var items = plan.planItems

        // 以当前第一个任务的开始时间为基准，后面任务依次顺延
        var currentStart = items[0].start
        for index in 0..<items.count {
            let duration = items[index].end.timeIntervalSince(items[index].start)
            items[index].start = currentStart
            items[index].end = currentStart.addingTimeInterval(duration)
            currentStart = items[index].end
        }

        plan.planItems = items
    }

    /// 将计划项上移一位
    func movePlanItemUp(_ item: PlanItem) {
        guard var plan = todayPlan,
              let index = plan.planItems.firstIndex(where: { $0.id == item.id }),
              index > 0 else { return }

        plan.planItems.swapAt(index, index - 1)
        recalculatePlanTimes(for: &plan)
        todayPlan = plan
        saveTodayPlan()
        NotificationManager.shared.cancelAllNotifications()
        NotificationManager.shared.scheduleNotifications(for: plan.planItems)
    }

    /// 将计划项下移一位
    func movePlanItemDown(_ item: PlanItem) {
        guard var plan = todayPlan,
              let index = plan.planItems.firstIndex(where: { $0.id == item.id }),
              index < plan.planItems.count - 1 else { return }

        plan.planItems.swapAt(index, index + 1)
        recalculatePlanTimes(for: &plan)
        todayPlan = plan
        saveTodayPlan()
        NotificationManager.shared.cancelAllNotifications()
        NotificationManager.shared.scheduleNotifications(for: plan.planItems)
    }

    func generatePlan(userInput: String = "") async {
        await MainActor.run {
            isGeneratingPlan = true
            errorMessage = nil
        }

        do {
            let workingBlocks = SettingsManager.shared.workingBlocks
            let today = Date()

            // 已有今日计划：传入现有计划，让 AI 在现有基础上插入/合并
            let existingPlan: DayPlan? = (todayPlan != nil && !(todayPlan!.planItems.isEmpty)) ? todayPlan : nil

            // 新的一天（今日无计划）：把当前未完成的任务当作「昨日未完成」让 AI 重新安排
            let carryOverTasks: [(id: UUID, title: String)] = existingPlan == nil
                ? tasks.filter { $0.status == .todo }.map { ($0.id, $0.title) }
                : []

            let response = try await QwenAPIService.shared.generatePlan(
                date: today,
                workingBlocks: workingBlocks,
                userInput: userInput,
                existingPlan: existingPlan,
                carryOverTasks: carryOverTasks
            )

            // 校验计划
            let validationError = validatePlan(planItems: response.planItems, workingBlocks: workingBlocks)
            if let error = validationError {
                await MainActor.run {
                    errorMessage = "计划校验失败: \(error)"
                    isGeneratingPlan = false
                }
                return
            }

            await MainActor.run {
                todayPlan = DayPlan(date: today, planItems: response.planItems, overflowTasks: response.overflowTasks)
                saveTodayPlan()

                // 合并任务列表：保留已有任务 ID 的完成状态，新项为 todo
                var taskStatusById: [UUID: Task.TaskStatus] = [:]
                for t in tasks {
                    taskStatusById[t.id] = t.status
                }
                
                // 收集 AI 返回的所有 ID
                let returnedIds = Set(response.planItems.map { $0.taskId } + response.overflowTasks.map { $0.taskId })
                
                var newTasks = response.planItems.map { item in
                    Task(
                        id: item.taskId,
                        raw: item.title,
                        title: item.title,
                        status: taskStatusById[item.taskId] ?? .todo
                    )
                }
                newTasks += response.overflowTasks.map { overflow in
                    Task(
                        id: overflow.taskId,
                        raw: overflow.title ?? "未安排",
                        title: overflow.title ?? "未安排",
                        status: taskStatusById[overflow.taskId] ?? .todo
                    )
                }
                
                // 检查 carryOverTasks 中是否有遗漏的，如果有，加回 newTasks
                for (id, title) in carryOverTasks {
                    if !returnedIds.contains(id) {
                         newTasks.append(Task(
                            id: id,
                            raw: title,
                            title: title,
                            status: .todo
                         ))
                    }
                }
                
                tasks = newTasks
                saveTasks()

                // 不在生成今日计划时自动创建通知，只更新计划与任务列表
                isGeneratingPlan = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isGeneratingPlan = false
            }
        }
    }

    private func validatePlan(planItems: [PlanItem], workingBlocks: [WorkingBlock]) -> String? {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)

        // 检查是否在工作时间段内，且不应在过去太久（允许 5 分钟误差）
        for item in planItems {
            // 允许 5 分钟的宽限期，避免刚生成的计划立即失效
            if item.end < now.addingTimeInterval(-300) {
                return "任务 \(item.title) 的结束时间已过"
            }
            
            var isInWorkingBlock = false
            for block in workingBlocks {
                if let range = block.toDateRange(on: today),
                   item.start >= range.start && item.end <= range.end {
                    isInWorkingBlock = true
                    break
                }
            }
            if !isInWorkingBlock {
                return "任务 \(item.title) 不在工作时间段内"
            }
        }

        // 检查是否重叠
        for i in 0..<planItems.count {
            for j in (i+1)..<planItems.count {
                let item1 = planItems[i]
                let item2 = planItems[j]
                if item1.start < item2.end && item2.start < item1.end {
                    return "任务 \(item1.title) 和 \(item2.title) 时间重叠"
                }
            }
        }

        return nil
    }

    // MARK: - Summary
    func loadTodaySummary() {
        todaySummary = FileStorageManager.shared.loadDaySummary(for: Date())
    }

    func saveTodaySummary() {
        if let summary = todaySummary {
            try? FileStorageManager.shared.saveDaySummary(summary, for: Date())
        }
    }

    func generateSummary() async {
        await MainActor.run {
            isGeneratingSummary = true
            errorMessage = nil
        }

        do {
            let planItems = todayPlan?.planItems ?? []
            let summaryText = try await QwenAPIService.shared.generateSummary(
                date: Date(),
                planItems: planItems,
                tasks: tasks
            )

            await MainActor.run {
                todaySummary = DaySummary(date: Date(), text: summaryText)
                saveTodaySummary()
                isGeneratingSummary = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isGeneratingSummary = false
            }
        }
    }

    // MARK: - Clues
    func generateClues(for task: Task) async {
        await MainActor.run {
            isGeneratingClues = true
            errorMessage = nil
        }

        do {
            var accumulatedClues = ""

            try await QwenAPIService.shared.generateClues(
                taskTitle: task.title,
                taskDescription: task.raw
            ) { chunk in
                _Concurrency.Task { @MainActor in
                    accumulatedClues += chunk
                    // 更新任务的线索
                    if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[index].clues = accumulatedClues
                    }
                }
            }

            await MainActor.run {
                saveTasks()
                isGeneratingClues = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isGeneratingClues = false
            }
        }
    }

    // MARK: - Auto Summary
    private func setupAutoSummary() {
        // 取消旧的定时器
        summaryTimer?.invalidate()

        guard SettingsManager.shared.autoSummaryEnabled else { return }

        // 解析设置的时间
        let timeString = SettingsManager.shared.autoSummaryTime
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return }

        let hour = components[0]
        let minute = components[1]

        // 计算下次触发时间
        let calendar = Calendar.current
        let now = Date()
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        guard var targetDate = calendar.date(from: dateComponents) else { return }

        // 如果今天的时间已过，设置为明天
        if targetDate <= now {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }

        let timeInterval = targetDate.timeIntervalSince(now)

        // 设置定时器
        summaryTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            _Concurrency.Task {
                await self?.generateSummary()
                // 生成后重新设置下一次定时器（明天同一时间）
                await MainActor.run {
                    self?.setupAutoSummary()
                }
            }
        }
    }

    func resetAutoSummary() {
        setupAutoSummary()
    }
}
