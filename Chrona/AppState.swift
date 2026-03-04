import Foundation
import SwiftUI

// MARK: - App State
class AppState: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var todayPlan: DayPlan?
    @Published var todaySummary: DaySummary?
    @Published var isGeneratingPlan = false
    @Published var isGeneratingSummary = false
    @Published var errorMessage: String?

    init() {
        loadTasks()
        loadTodayPlan()
        loadTodaySummary()
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
            let carryOverTitles: [String] = existingPlan == nil
                ? tasks.filter { $0.status == .todo }.map { $0.title }
                : []

            let response = try await QwenAPIService.shared.generatePlan(
                date: today,
                workingBlocks: workingBlocks,
                userInput: userInput,
                existingPlan: existingPlan,
                carryOverTitles: carryOverTitles
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
                tasks = newTasks
                saveTasks()

                // 重建通知
                NotificationManager.shared.cancelAllNotifications()
                NotificationManager.shared.scheduleNotifications(for: response.planItems)

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
        let today = Date()

        // 检查是否在工作时间段内
        for item in planItems {
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
}
