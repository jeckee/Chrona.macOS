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
    func refreshTodayPlanNotifications() {
        NotificationManager.shared.cancelAllNotifications()
        if let plan = todayPlan {
            NotificationManager.shared.scheduleNotifications(for: plan.planItems)
        }
    }

    init() {
        loadTasks()
        loadTodayPlan()
        loadTodaySummary()

        // 启动时重建提醒
        refreshTodayPlanNotifications()

        // 启动定时总结
        setupAutoSummary()
    }

    // MARK: - Tasks
    func loadTasks() {
        tasks = FileStorageManager.shared.loadTasks()
    }

    func saveTasks() {
        FileStorageManager.shared.saveTasksAsync(tasks)
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
            if tasks[index].status == .done {
                tasks[index].status = .todo
                tasks[index].startedAt = nil
                tasks[index].pausedAt = nil
                tasks[index].completedAt = nil
            } else {
                completeTask(taskId: task.id, shouldSave: false)
            }
            saveTasks()
        }
    }

    func startTask(taskId: UUID) {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("[AppState] startTask(\(taskId)) triggered")
        
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let now = Date()
        if tasks[index].startedAt == nil {
            tasks[index].startedAt = now
        }
        tasks[index].status = .inProgress
        tasks[index].pausedAt = nil
        tasks[index].completedAt = nil
        saveTasks()
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("[AppState] startTask(\(taskId)) main thread execution finished in \(String(format: "%.2f", duration))ms")
    }

    func pauseTask(taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let now = Date()
        if tasks[index].startedAt == nil {
            tasks[index].startedAt = now
        }
        tasks[index].status = .paused
        tasks[index].pausedAt = now
        tasks[index].completedAt = nil
        saveTasks()
    }

    func completeTask(taskId: UUID) {
        completeTask(taskId: taskId, shouldSave: true)
    }

    func updateTaskConclusion(taskId: UUID, conclusion: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let trimmed = conclusion.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[index].conclusion = trimmed.isEmpty ? nil : trimmed
        saveTasks()
    }

    private func completeTask(taskId: UUID, shouldSave: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let now = Date()
        if tasks[index].startedAt == nil {
            tasks[index].startedAt = now
        }
        tasks[index].status = .done
        tasks[index].completedAt = now
        if shouldSave {
            saveTasks()
        }
    }

    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }

    /// 完成计划项：将对应任务标为已完成
    func completePlanItem(_ item: PlanItem) {
        completeTask(taskId: item.taskId)
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

    /// 将未安排任务上移一位
    func moveOverflowTaskUp(_ overflow: OverflowTask) {
        guard var plan = todayPlan,
              let index = plan.overflowTasks.firstIndex(where: { $0.taskId == overflow.taskId }),
              index > 0 else { return }

        plan.overflowTasks.swapAt(index, index - 1)
        todayPlan = plan
        saveTodayPlan()
    }

    /// 将未安排任务下移一位
    func moveOverflowTaskDown(_ overflow: OverflowTask) {
        guard var plan = todayPlan,
              let index = plan.overflowTasks.firstIndex(where: { $0.taskId == overflow.taskId }),
              index < plan.overflowTasks.count - 1 else { return }

        plan.overflowTasks.swapAt(index, index + 1)
        todayPlan = plan
        saveTodayPlan()
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
        refreshTodayPlanNotifications()
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

    /// 根据当前顺序自动重新排布时间段（保持每个任务的时长不变），并避开非工作时间段
    private func recalculatePlanTimes(for plan: inout DayPlan) {
        guard !plan.planItems.isEmpty else { return }

        let ranges = SettingsManager.shared.workingBlocks
            .compactMap { $0.toDateRange(on: plan.date) }
            .filter { $0.start < $0.end }
            .sorted { $0.start < $1.start }

        var items = plan.planItems
        var currentStart = items[0].start

        if let alignedStart = nextWorkingStart(atOrAfter: currentStart, in: ranges) {
            currentStart = alignedStart
        }

        if ranges.isEmpty {
            for index in 0..<items.count {
                let duration = max(items[index].end.timeIntervalSince(items[index].start), 60)
                items[index].start = currentStart
                items[index].end = currentStart.addingTimeInterval(duration)
                currentStart = items[index].end
            }
            plan.planItems = items
            return
        }

        for index in 0..<items.count {
            let duration = max(items[index].end.timeIntervalSince(items[index].start), 60)
            let scheduled = scheduleInWorkingRanges(startingAt: currentStart, duration: duration, ranges: ranges)
            items[index].start = scheduled.start
            items[index].end = scheduled.end
            currentStart = scheduled.end
        }

        plan.planItems = items
    }

    private func nextWorkingStart(atOrAfter date: Date, in ranges: [(start: Date, end: Date)]) -> Date? {
        for range in ranges {
            if date < range.start { return range.start }
            if date >= range.start && date < range.end { return date }
        }
        return nil
    }

    private func scheduleInWorkingRanges(startingAt currentStart: Date, duration: TimeInterval, ranges: [(start: Date, end: Date)]) -> (start: Date, end: Date) {
        guard !ranges.isEmpty else {
            return (currentStart, currentStart.addingTimeInterval(duration))
        }

        if let currentRangeIndex = ranges.firstIndex(where: { $0.end > currentStart }) {
            let currentRange = ranges[currentRangeIndex]
            let candidateStart = max(currentStart, currentRange.start)
            let candidateEnd = candidateStart.addingTimeInterval(duration)

            if candidateEnd <= currentRange.end {
                return (candidateStart, candidateEnd)
            }

            if currentRangeIndex + 1 < ranges.count {
                for nextIndex in (currentRangeIndex + 1)..<ranges.count {
                    let nextRange = ranges[nextIndex]
                    let nextStart = nextRange.start
                    let nextEnd = nextStart.addingTimeInterval(duration)
                    if nextEnd <= nextRange.end {
                        return (nextStart, nextEnd)
                    }
                }
            }

            let fallbackStart = max(currentStart, ranges[ranges.count - 1].start)
            return (fallbackStart, fallbackStart.addingTimeInterval(duration))
        }

        return (currentStart, currentStart.addingTimeInterval(duration))
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
        refreshTodayPlanNotifications()
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
        refreshTodayPlanNotifications()
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
                var existingTaskById: [UUID: Task] = [:]
                for task in tasks {
                    existingTaskById[task.id] = task
                }
                
                // 收集 AI 返回的所有 ID
                let returnedIds = Set(response.planItems.map { $0.taskId } + response.overflowTasks.map { $0.taskId })
                
                var newTasks: [Task] = response.planItems.map { item -> Task in
                    let existingTask = existingTaskById[item.taskId]
                    return Task(
                        id: item.taskId,
                        raw: item.title,
                        title: item.title,
                        status: existingTask?.status ?? .todo,
                        startedAt: existingTask?.startedAt,
                        pausedAt: existingTask?.pausedAt,
                        completedAt: existingTask?.completedAt,
                        conclusion: existingTask?.conclusion
                    )
                }
                newTasks += response.overflowTasks.map { overflow -> Task in
                    let existingTask = existingTaskById[overflow.taskId]
                    return Task(
                        id: overflow.taskId,
                        raw: overflow.title ?? "未安排",
                        title: overflow.title ?? "未安排",
                        status: existingTask?.status ?? .todo,
                        startedAt: existingTask?.startedAt,
                        pausedAt: existingTask?.pausedAt,
                        completedAt: existingTask?.completedAt,
                        conclusion: existingTask?.conclusion
                    )
                }
                
                // 检查 carryOverTasks 中是否有遗漏的，如果有，加回 newTasks
                for (id, title) in carryOverTasks {
                    if !returnedIds.contains(id) {
                        if let existingTask = existingTaskById[id] {
                            newTasks.append(existingTask)
                        } else {
                            newTasks.append(Task(
                                id: id,
                                raw: title,
                                title: title,
                                status: .todo
                            ))
                        }
                    }
                }
                
                tasks = newTasks
                saveTasks()

                refreshTodayPlanNotifications()
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
