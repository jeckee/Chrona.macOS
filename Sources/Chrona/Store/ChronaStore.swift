import Foundation
import SwiftUI

/// 应用级状态与业务动作入口：统一内存状态、持久化与排期/任务字段一致性。
@MainActor
final class ChronaStore: ObservableObject {

    // MARK: - Published state

    @Published private(set) var tasks: [ChronaTask] = []
    @Published private(set) var scheduleBlocks: [ScheduleBlock] = []
    @Published private(set) var settings: AppSettings = .default

    /// 当前日期视图（仅用于本地过滤与权限控制）。
    /// 约定：始终保持为当天 `startOfDay`，避免跨时区/时间戳导致的“同一天”判断偏差。
    @Published private(set) var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    /// 侧栏/详情当前选中的任务；由 UI 绑定，加载后若失效会回退到首个可用任务。
    @Published var selection: UUID?

    /// 是否至少成功完成过一次从磁盘的初始加载。
    @Published private(set) var isLoaded: Bool = false

    /// 最近一次操作或加载中的错误（成功写入或加载后可由调用方清空，见 `clearLastError()`）。
    @Published private(set) var lastError: Error?
    @Published private(set) var scheduleExecutionState: ScheduleExecutionState = .idle

    /// 轻提示：仅用于“进入 today 自动延续未完成任务”的场景。
    @Published private(set) var carryOverToast: String?
    private var carryOverToastClearTask: Task<Void, Never>?

    // MARK: - Daily Summary（右侧详情；历史日仅读本地，今天可 AI 生成）

    @Published private(set) var isShowingTodaySummary: Bool = false
    @Published private(set) var todaySummaryState: TodaySummaryState = .idle
    @Published private(set) var todaySummaryContent: String = ""
    @Published private(set) var todaySummaryGeneratedAt: Date?

    // MARK: - Dependencies

    private let storage: LocalStorageServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let taskSchedulingService: TaskSchedulingServiceProtocol
    private let summaryService: SummaryServiceProtocol

    // MARK: - Init

    init(
        storage: LocalStorageServiceProtocol = LocalStorageService(),
        notificationService: NotificationServiceProtocol = NotificationService(),
        taskSchedulingService: TaskSchedulingServiceProtocol = TaskSchedulingService(),
        summaryService: SummaryServiceProtocol = SummaryService()
    ) {
        self.storage = storage
        self.notificationService = notificationService
        self.taskSchedulingService = taskSchedulingService
        self.summaryService = summaryService
    }

    // MARK: - Errors

    func clearLastError() {
        lastError = nil
    }

    private func record(_ error: Error) {
        lastError = error
    }

    // MARK: - Load

    /// 从本地加载任务、排期块与设置；首次无文件时使用存储层默认值。
    /// 加载后会做任务完成字段与排期关系的一致性整理，必要时写回磁盘。
    func loadInitialData() {
        do {
            tasks = try storage.loadTasks()
            scheduleBlocks = try storage.loadScheduleBlocks()
            settings = try storage.loadSettings()
        } catch {
            record(error)
            return
        }

        isLoaded = true

        if normalizeLoadedTasksAndBlocks() {
            persistNormalizedData()
        }

        // 首次加载：若当前 selectedDate 已经是 today，则执行一次迁移闭环。
        if selectedDateKind == .today {
            _ = carryOverPastIncompleteTasksToToday()
        }

        reconcileSelectionAfterLoad()

        // 根据磁盘恢复提醒（仅为“今天(taskDate)”的排期块创建/更新本地通知）。
        Task { [weak self] in
            guard let self else { return }
            await self.refreshTaskRemindersForToday()
        }
    }

    // MARK: - Date navigation

    func shiftSelectedDate(byDays days: Int) {
        let cal = Calendar.current
        let newDate = cal.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        setSelectedDate(newDate)
    }

    private func setSelectedDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        guard normalized != selectedDate else { return }
        selectedDate = normalized

        // 若正在看 Summary，按新日期重新加载（今天可走 AI；过去/未来仅读本地已存）。
        if isShowingTodaySummary {
            Task { [weak self] in
                guard let self else { return }
                await self.loadOrGenerateTodaySummary(forceRefresh: false)
            }
        }

        // 仅当切到 today 时执行迁移闭环。
        if selectedDateKind == .today {
            _ = carryOverPastIncompleteTasksToToday()
        }

        reconcileSelectionAfterDateChange()
    }

    // MARK: - Summary

    /// 是否允许使用「Refresh」重新调用 AI（仅选中日为今天时为 true）。
    var canRegenerateDailySummary: Bool { selectedDateKind == .today }

    func setSelection(_ id: UUID?) {
        selection = id
        if id != nil { isShowingTodaySummary = false }
    }

    /// 顶部 Summary 按钮：右侧切到 Summary；今天可生成/刷新，其它日期仅展示已保存内容。
    func showTodaySummary() {
        isShowingTodaySummary = true
        selection = nil

        // 防止用户重复点击导致并发生成。
        switch todaySummaryState {
        case .loadingSavedSummary, .generating, .streaming:
            return
        default:
            break
        }

        Task { [weak self] in
            guard let self else { return }
            await self.loadOrGenerateTodaySummary(forceRefresh: false)
        }
    }

    /// Summary 视图右上角 Refresh：仅今天可用；强制重新生成（streaming），成功后覆盖保存。
    func refreshTodaySummary() {
        guard canRegenerateDailySummary else { return }

        isShowingTodaySummary = true
        selection = nil

        // 生成中禁用再次点击。
        switch todaySummaryState {
        case .loadingSavedSummary, .generating, .streaming:
            return
        default:
            break
        }

        Task { [weak self] in
            guard let self else { return }
            await self.loadOrGenerateTodaySummary(forceRefresh: true)
        }
    }

    private func loadOrGenerateTodaySummary(forceRefresh: Bool) async {
        let sessionDay = Calendar.current.startOfDay(for: selectedDate)
        func isStillSameSessionDay() -> Bool {
            Calendar.current.isDate(selectedDate, inSameDayAs: sessionDay)
        }

        // 1) 非今天：只读本地（不调用 AI）
        if selectedDateKind != .today {
            todaySummaryState = .loadingSavedSummary
            let saved = try? storage.loadDailySummary(for: sessionDay)
            guard isStillSameSessionDay() else { return }
            if let saved {
                todaySummaryContent = saved.content
                todaySummaryGeneratedAt = saved.generatedAt
                todaySummaryState = .success
            } else {
                todaySummaryContent = ""
                todaySummaryGeneratedAt = nil
                todaySummaryState = .failure("No saved summary for this day.")
            }
            return
        }

        // 2) 收集 today 任务（包含 done 与未 done）
        let calendar = Calendar.current
        let dayTasks = tasks.filter { calendar.isDate($0.taskDate, inSameDayAs: selectedDate) }

        guard !dayTasks.isEmpty else {
            todaySummaryState = .failure("No tasks for today")
            todaySummaryContent = ""
            todaySummaryGeneratedAt = nil
            return
        }

        // 3) 检查 provider / apiKey
        let provider = settings.selectedProvider
        guard !provider.models.isEmpty else {
            todaySummaryState = .failure(AIServiceError.providerNotSelected.userMessage)
            return
        }

        let apiKey = settings.trimmedAPIKeyForSelectedProvider()
        guard !apiKey.isEmpty else {
            todaySummaryState = .failure(
                "The API key for \"\(settings.selectedProvider.displayName)\" is empty. Add it in Settings first."
            )
            return
        }

        let modelId = settings.selectedModelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultModelId
            : settings.selectedModelId

        // 4) 本地 summary 优先（首次 click）
        todaySummaryState = .loadingSavedSummary

        let savedSummary = try? storage.loadDailySummary(for: selectedDate)
        if !forceRefresh, let savedSummary {
            guard isStillSameSessionDay() else { return }
            todaySummaryContent = savedSummary.content
            todaySummaryGeneratedAt = savedSummary.generatedAt
            todaySummaryState = .success
            return
        }

        // 5) 需要生成：保留旧内容（refresh 失败要回退）
        if forceRefresh, let savedSummary {
            todaySummaryContent = savedSummary.content
            todaySummaryGeneratedAt = savedSummary.generatedAt
        } else if !forceRefresh {
            todaySummaryContent = ""
            todaySummaryGeneratedAt = nil
        }

        todaySummaryState = .generating

        var draft = ""
        var receivedAnyToken = false

        do {
            let stream = try summaryService.generateSummaryStream(
                date: selectedDate,
                tasks: dayTasks,
                provider: provider,
                apiKey: apiKey,
                modelId: modelId
            )

            for try await token in stream {
                guard isStillSameSessionDay() else { return }
                receivedAnyToken = true
                if todaySummaryState != .streaming {
                    todaySummaryState = .streaming
                }
                draft.append(token)
                todaySummaryContent = Self.normalizeSummaryPlainText(draft)
            }

            guard isStillSameSessionDay() else { return }

            let finalText = Self.normalizeSummaryPlainText(draft)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard receivedAnyToken, !finalText.isEmpty else {
                throw AIServiceError.invalidResponse
            }

            // 6) 生成完成后：保存到本地（成功后覆盖）
            let newSummary = DailySummary(date: selectedDate, content: finalText)
            do {
                try storage.saveDailySummary(newSummary)
            } catch {
                guard isStillSameSessionDay() else { return }
                // 本地保存失败：不覆盖旧内容
                if let savedSummary {
                    todaySummaryContent = savedSummary.content
                    todaySummaryGeneratedAt = savedSummary.generatedAt
                } else {
                    todaySummaryContent = ""
                    todaySummaryGeneratedAt = nil
                }
                todaySummaryState = .failure("Failed to save summary. Please try again.")
                return
            }

            guard isStillSameSessionDay() else { return }
            todaySummaryGeneratedAt = newSummary.generatedAt
            todaySummaryContent = finalText
            todaySummaryState = .success
        } catch {
            // 7) 流式过程中失败：停止并给清晰错误提示，不写入损坏 summary
            let message: String
            if let aiError = error as? AIServiceError {
                message = aiError.userMessage
            } else {
                message = error.localizedDescription
            }

            guard isStillSameSessionDay() else { return }

            if forceRefresh, let savedSummary {
                todaySummaryContent = savedSummary.content
                todaySummaryGeneratedAt = savedSummary.generatedAt
            }

            todaySummaryState = .failure(message)
        }
    }

    // MARK: - Carry over past tasks (today entry only)

    /// 将所有“过去日期中的未完成任务”迁移到今天，并统一进入 today 的 `UNSCHEDULED` 列表（todo + 无排期）。
    ///
    /// 规则（严格按题意）：
    /// - 候选：`task.taskDate < today` 且 `task.status != .done`
    /// - 迁移后：`taskDate=today`、`status=.todo`、`isScheduled=false`、`scheduleBlockId=nil`、`updatedAt=now`
    /// - 若原任务有关联旧 `ScheduleBlock`：删除旧 blocks（不继承旧时间段）
    /// - 取消旧 reminders（仅取消被删除的 ScheduleBlock 关联提醒），不为新迁移的未排期任务创建提醒
    /// - 不复制任务，只原地修改任务本体
    /// - Returns：迁移到今天的任务数量
    @discardableResult
    func carryOverPastIncompleteTasksToToday() -> Int {
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)

        // 严格筛选候选任务
        let movedTaskIds = Set(
            tasks
                .filter { $0.taskDate < todayStart && $0.status != .done }
                .map(\.id)
        )
        guard !movedTaskIds.isEmpty else { return 0 }

        var movedCount = 0
        var updatedTasks = tasks
        for i in updatedTasks.indices {
            let task = updatedTasks[i]
            guard task.taskDate < todayStart && task.status != .done else { continue }

            movedCount += 1
            updatedTasks[i].taskDate = todayStart
            updatedTasks[i].status = .todo
            updatedTasks[i].isScheduled = false
            updatedTasks[i].scheduleBlockId = nil
            updatedTasks[i].completedAt = nil
            updatedTasks[i].updatedAt = now
        }

        // 删除旧 ScheduleBlock + 取消其关联旧提醒
        let removedBlocks = scheduleBlocks.filter { movedTaskIds.contains($0.taskId) }
        let reminderIds = removedBlocks.map { Self.reminderIdentifier(for: $0.id) }
        notificationService.cancelNotifications(identifiers: reminderIds)

        var updatedBlocks = scheduleBlocks
        updatedBlocks.removeAll { movedTaskIds.contains($0.taskId) }

        tasks = updatedTasks
        scheduleBlocks = updatedBlocks
        saveTasks()
        saveScheduleBlocks()

        // 轻提示（可选）
        carryOverToastClearTask?.cancel()
        carryOverToastClearTask = nil
        let taskWord = movedCount == 1 ? "task" : "tasks"
        carryOverToast = "\(movedCount) unfinished \(taskWord) carried over to today"
        carryOverToastClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { self?.carryOverToast = nil }
        }

        return movedCount
    }

    // MARK: - Permission (based on selectedDate)

    private enum SelectedDateKind {
        case today
        case past
        case future
    }

    private var selectedDateKind: SelectedDateKind {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if cal.isDate(selectedDate, inSameDayAs: today) { return .today }
        return selectedDate < today ? .past : .future
    }

    var canAddTask: Bool { selectedDateKind != .past }
    var canDeleteTask: Bool { selectedDateKind != .past }
    var canScheduleTask: Bool { selectedDateKind == .today }
    var canChangeTaskStatus: Bool { selectedDateKind == .today }
    var canEditConclusion: Bool { selectedDateKind == .today }
    var canEditTaskCoreFields: Bool { selectedDateKind != .past }

    var isScheduling: Bool {
        if case .scheduling = scheduleExecutionState { return true }
        return false
    }

    func resetScheduleExecutionState() {
        if case .scheduling = scheduleExecutionState { return }
        scheduleExecutionState = .idle
    }

    // MARK: - List buckets (UI)

    /// 按侧栏分区规则返回任务。
    /// - `scheduled`：按排期时间段开始时间升序（再按结束时间、`sortOrder` 兜底）
    /// - 其他分区：按 `sortOrder` 升序
    /// - 已完成：仅看 `status == .done`
    /// - 已排期：`isScheduled`、非空 `scheduleBlockId`，且在 `scheduleBlocks` 中存在对应块且 `taskId` 一致
    /// - 未排期：其余非完成任务
    func tasks(in bucket: TaskBucket) -> [ChronaTask] {
        let filtered = tasks.filter { isTaskForSelectedDate($0) && sidebarBucket(for: $0) == bucket }

        guard bucket == .scheduled else {
            return filtered.sorted { $0.sortOrder < $1.sortOrder }
        }

        let scheduleByTaskId = Dictionary(uniqueKeysWithValues: scheduleBlocks.map { ($0.taskId, $0) })
        return filtered.sorted { lhs, rhs in
            let lhsBlock = scheduleByTaskId[lhs.id]
            let rhsBlock = scheduleByTaskId[rhs.id]

            let lhsStart = lhsBlock?.startAt ?? .distantFuture
            let rhsStart = rhsBlock?.startAt ?? .distantFuture
            if lhsStart != rhsStart { return lhsStart < rhsStart }

            let lhsEnd = lhsBlock?.endAt ?? .distantFuture
            let rhsEnd = rhsBlock?.endAt ?? .distantFuture
            if lhsEnd != rhsEnd { return lhsEnd < rhsEnd }

            return lhs.sortOrder < rhs.sortOrder
        }
    }

    /// 与 `tasks(in:)` 相同的分区规则，供列表行/卡片展示与操作分支使用。
    func sidebarBucket(for task: ChronaTask) -> TaskBucket {
        Self.bucket(for: task, scheduleBlocks: scheduleBlocks)
    }

    func scheduleBlock(forTaskId taskId: UUID) -> ScheduleBlock? {
        guard let task = tasks.first(where: { $0.id == taskId }) else {
            return scheduleBlocks.first { $0.taskId == taskId }
        }
        if let bid = task.scheduleBlockId,
           let match = scheduleBlocks.first(where: { $0.id == bid && $0.taskId == taskId }) {
            return match
        }
        return scheduleBlocks.first { $0.taskId == taskId }
    }

    func binding(for id: UUID) -> Binding<ChronaTask> {
        Binding(
            get: {
                self.tasks.first { $0.id == id }
                    ?? ChronaTask(
                        id: id,
                        taskDate: self.selectedDate,
                        title: "",
                        note: nil,
                        status: .todo,
                        sortOrder: 0
                    )
            },
            set: { newValue in
                guard let idx = self.tasks.firstIndex(where: { $0.id == id }) else { return }
                var list = self.tasks
                list[idx] = newValue
                self.tasks = list
                self.saveTasks()
            }
        )
    }

    // MARK: - Tasks — CRUD

    func addTask(title: String, note: String? = nil) {
        guard canAddTask else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        var list = tasks
        let order = nextSortOrder()
        let task = ChronaTask(
            taskDate: selectedDate,
            title: trimmed,
            note: note,
            status: .todo,
            priority: .medium,
            isScheduled: false,
            scheduleBlockId: nil,
            sortOrder: order,
            completedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        list.append(task)
        tasks = list
        selection = task.id
        saveTasks()
    }

    func deleteTask(id: UUID) {
        guard canDeleteTask else { return }
        let removedBlocks = scheduleBlocks.filter { $0.taskId == id }
        let reminderIds = removedBlocks.map { Self.reminderIdentifier(for: $0.id) }

        var list = tasks
        guard let idx = indexOfTask(id: id) else { return }
        list.remove(at: idx)
        tasks = list

        var blocks = scheduleBlocks
        blocks.removeAll { $0.taskId == id }
        scheduleBlocks = blocks

        saveTasks()
        saveScheduleBlocks()

        // 删除任务需要取消对应提醒（如已创建）。
        notificationService.cancelNotifications(identifiers: reminderIds)
        if selection == id {
            reconcileSelectionAfterDateChange()
        }
    }

    func updateTaskTitle(id: UUID, title: String) {
        guard canEditTaskCoreFields else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = indexOfTask(id: id) else { return }

        var list = tasks
        list[idx].title = trimmed
        list[idx].updatedAt = Date()
        tasks = list
        saveTasks()
    }

    func updateTaskEstimatedMinutes(id: UUID, minutes: Int) {
        updateTaskEstimatedMinutesWithScheduleAdjustment(id: id, minutes: minutes)
    }

    func updateTaskEstimatedMinutesWithScheduleAdjustment(id: UUID, minutes: Int) {
        guard canEditTaskCoreFields else { return }
        let normalizedMinutes = max(1, minutes)
        guard let taskIndex = indexOfTask(id: id) else { return }

        let task = tasks[taskIndex]
        let now = Date()

        if !task.isScheduled || scheduleBlock(forTaskId: id) == nil {
            var list = tasks
            list[taskIndex].estimatedMinutes = normalizedMinutes
            list[taskIndex].isDurationUserEdited = true
            list[taskIndex].updatedAt = now
            tasks = list
            saveTasks()
            return
        }

        guard let currentBlockIndex = scheduleBlocks.firstIndex(where: { $0.taskId == id }) else { return }
        let originalBlock = scheduleBlocks[currentBlockIndex]
        let originalEnd = originalBlock.endAt
        let proposedEnd = Calendar.current.date(byAdding: .minute, value: normalizedMinutes, to: originalBlock.startAt)
            ?? originalBlock.startAt.addingTimeInterval(TimeInterval(normalizedMinutes * 60))
        let baseDate = Calendar.current.startOfDay(for: originalBlock.startAt)

        // B 策略：若会撞到后方固定时间锚点，则将当前任务结束时间截断到锚点前。
        let anchorAfterCurrent = firstFixedAnchorStartAfter(
            date: originalBlock.startAt,
            on: baseDate,
            in: scheduleBlocks,
            tasks: tasks
        )
        let boundedEnd: Date
        if let anchorAfterCurrent, proposedEnd > anchorAfterCurrent {
            boundedEnd = anchorAfterCurrent
        } else {
            boundedEnd = proposedEnd
        }
        let boundedDurationMinutes = max(1, Int(boundedEnd.timeIntervalSince(originalBlock.startAt) / 60))

        var tasksDraft = tasks
        var blocksDraft = scheduleBlocks

        tasksDraft[taskIndex].estimatedMinutes = boundedDurationMinutes
        tasksDraft[taskIndex].isDurationUserEdited = true
        tasksDraft[taskIndex].updatedAt = now
        blocksDraft[currentBlockIndex].endAt = boundedEnd
        blocksDraft[currentBlockIndex].updatedAt = now

        let following = blocksDraft
            .enumerated()
            .filter { _, block in
                block.taskId != id
                    && Calendar.current.isDate(block.startAt, inSameDayAs: baseDate)
                    && block.startAt >= originalEnd
            }
            .sorted { $0.element.startAt < $1.element.startAt }

        var cursor = boundedEnd
        var originalCursor = originalEnd
        for (index, block) in following {
            // A 策略：只调整“严格连续”的后续块；一旦不连续，立即停止局部联动。
            guard areStrictlyContiguous(leftEnd: originalCursor, rightStart: block.startAt) else { break }
            guard !isFixedTimeTask(taskId: block.taskId, in: tasksDraft) else { break }
            let durationSeconds = max(60, block.endAt.timeIntervalSince(block.startAt))
            let shiftedStart = cursor
            let shiftedEnd = shiftedStart.addingTimeInterval(durationSeconds)

            if let anchorStart = firstFixedAnchorStartAfter(date: boundedEnd, on: baseDate, in: blocksDraft, tasks: tasksDraft),
               shiftedEnd > anchorStart {
                break
            }

            blocksDraft[index].startAt = shiftedStart
            blocksDraft[index].endAt = shiftedEnd
            blocksDraft[index].updatedAt = now
            cursor = shiftedEnd
            originalCursor = block.endAt
        }

        tasks = tasksDraft
        scheduleBlocks = blocksDraft
        saveTasks()
        saveScheduleBlocks()

        Task { [weak self] in
            guard let self else { return }
            await self.refreshTaskRemindersForToday()
        }
    }

    func updateTaskPriority(id: UUID, priority: ChronaTaskPriority) {
        guard canEditTaskCoreFields else { return }
        guard let idx = indexOfTask(id: id) else { return }

        var list = tasks
        guard list[idx].priority != priority else { return }
        list[idx].priority = priority
        list[idx].isPriorityUserEdited = true
        list[idx].updatedAt = Date()
        tasks = list
        saveTasks()
    }

    func updateTaskNote(id: UUID, note: String?) {
        guard let idx = indexOfTask(id: id) else { return }

        var list = tasks
        list[idx].note = note
        list[idx].updatedAt = Date()
        tasks = list
        saveTasks()
    }

    // MARK: - Tasks — lifecycle

    func startTask(id: UUID) {
        guard canChangeTaskStatus else { return }
        guard let idx = indexOfTask(id: id) else { return }
        let reminderIds = reminderIdentifiers(forTaskId: id)

        var list = tasks
        let current = list[idx].status
        guard current == .todo || current == .paused else { return }

        var t = list[idx]
        t.status = .inProgress
        if t.completedAt != nil {
            t.completedAt = nil
        }
        t.updatedAt = Date()
        list[idx] = t
        tasks = list
        saveTasks()

        // 任务进入 inProgress 后不应再收到“即将开始”提醒。
        notificationService.cancelNotifications(identifiers: reminderIds)
    }

    func pauseTask(id: UUID) {
        guard canChangeTaskStatus else { return }
        guard let idx = indexOfTask(id: id) else { return }

        var list = tasks
        guard list[idx].status == .inProgress else { return }

        list[idx].status = .paused
        list[idx].updatedAt = Date()
        tasks = list
        saveTasks()

        if let block = scheduleBlock(forTaskId: id) {
            Task { [weak self] in
                guard let self else { return }
                await self.scheduleTaskReminderIfNeeded(for: block)
            }
        }
    }

    func completeTask(id: UUID) {
        guard canChangeTaskStatus else { return }
        guard let idx = indexOfTask(id: id) else { return }
        let reminderIds = reminderIdentifiers(forTaskId: id)

        var list = tasks
        let current = list[idx].status
        guard current == .inProgress || current == .paused else { return }

        var t = list[idx]
        let now = Date()
        t.status = .done
        t.completedAt = now
        t.updatedAt = now
        list[idx] = t
        tasks = list
        saveTasks()

        // 从 Scheduled 进入 Completed 后，不应继续保留该任务的开始前提醒。
        notificationService.cancelNotifications(identifiers: reminderIds)
    }

    func resetTaskToTodo(id: UUID) {
        guard canChangeTaskStatus else { return }
        guard let idx = indexOfTask(id: id) else { return }

        var list = tasks
        guard list[idx].status == .done else { return }

        list[idx].status = .todo
        list[idx].completedAt = nil
        list[idx].updatedAt = Date()
        tasks = list
        saveTasks()

        // 若任务本身仍有有效排期块，恢复为 todo 后会重新回到 Scheduled，需要补建提醒。
        if let block = scheduleBlock(forTaskId: id) {
            Task { [weak self] in
                guard let self else { return }
                await self.scheduleTaskReminderIfNeeded(for: block)
            }
        }
    }

    func updateConclusion(id: UUID, conclusion: String?) {
        guard canEditConclusion else { return }
        guard let idx = indexOfTask(id: id) else { return }

        var list = tasks
        list[idx].conclusion = conclusion
        list[idx].updatedAt = Date()
        tasks = list
        saveTasks()
    }

    // MARK: - Schedule

    /// 手动加入排期：排在当前选中日、所有已有 Scheduled 任务之后；在剩余工作时段内取默认时长（`estimatedMinutes` 或 30 分钟）；无匹配工作段时退化为「不早于当前时间且晚于上述排期」的起点 + 默认时长。
    func scheduleTaskWithDefaultSlot(id: UUID) {
        guard canScheduleTask else { return }
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        guard task.status != .done else { return }
        guard sidebarBucket(for: task) != .scheduled else { return }

        let durationMinutes = max(1, task.estimatedMinutes ?? 30)
        let calendar = Calendar.current
        let now = Date()
        let sortedRanges = settings.workingHours.ranges.sorted { $0.startMinutes < $1.startMinutes }

        let afterOthers = latestScheduledBlockEndOnSelectedDay(excludingTaskId: id).map { max(now, $0) } ?? now

        var startAt: Date = afterOthers
        var endAt: Date = calendar.date(byAdding: .minute, value: durationMinutes, to: afterOthers)
            ?? afterOthers.addingTimeInterval(TimeInterval(durationMinutes * 60))

        let todayComps = calendar.dateComponents([.year, .month, .day], from: now)

        for range in sortedRanges where range.startMinutes < range.endMinutes {
            var sc = todayComps; sc.hour = range.startMinutes / 60; sc.minute = range.startMinutes % 60; sc.second = 0
            var ec = todayComps; ec.hour = range.endMinutes / 60; ec.minute = range.endMinutes % 60; ec.second = 0
            guard let rangeStart = calendar.date(from: sc),
                  let rangeEnd = calendar.date(from: ec) else { continue }

            if rangeEnd <= afterOthers { continue }

            let slotStart = max(rangeStart, afterOthers)
            var slotEnd = calendar.date(byAdding: .minute, value: durationMinutes, to: slotStart)
                ?? slotStart.addingTimeInterval(TimeInterval(durationMinutes * 60))
            if slotEnd > rangeEnd { slotEnd = rangeEnd }
            if slotEnd <= slotStart { continue }

            startAt = slotStart
            endAt = slotEnd
            break
        }

        scheduleTask(id: id, startAt: startAt, endAt: endAt, source: .manual)
    }

    func scheduleTask(
        id: UUID,
        startAt: Date,
        endAt: Date,
        source: ScheduleSource = .manual
    ) {
        guard canScheduleTask else { return }
        guard let tIdx = indexOfTask(id: id) else { return }
        guard startAt < endAt else {
            record(ChronaStoreError.invalidScheduleRange)
            return
        }

        // 先缓存旧提醒标识：排期“改时间”会产生新 ScheduleBlock，需要取消旧的待触发通知。
        let oldBlocks = scheduleBlocks.filter { $0.taskId == id }
        let oldReminderIds = oldBlocks.map { Self.reminderIdentifier(for: $0.id) }

        var blocks = scheduleBlocks
        blocks.removeAll { $0.taskId == id }

        let now = Date()
        let newBlock = ScheduleBlock(
            taskId: id,
            startAt: startAt,
            endAt: endAt,
            source: source,
            createdAt: now,
            updatedAt: now
        )
        blocks.append(newBlock)
        scheduleBlocks = blocks

        var list = tasks
        list[tIdx].isScheduled = true
        list[tIdx].scheduleBlockId = newBlock.id
        list[tIdx].updatedAt = now
        tasks = list

        saveScheduleBlocks()
        saveTasks()

        notificationService.cancelNotifications(identifiers: oldReminderIds)
        Task { [weak self] in
            guard let self else { return }
            await self.scheduleTaskReminderIfNeeded(for: newBlock)
        }
    }

    func unscheduleTask(id: UUID) {
        guard canScheduleTask else { return }
        guard let tIdx = indexOfTask(id: id) else { return }

        let removedBlocks = scheduleBlocks.filter { $0.taskId == id }
        let reminderIds = removedBlocks.map { Self.reminderIdentifier(for: $0.id) }

        var blocks = scheduleBlocks
        blocks.removeAll { $0.taskId == id }
        scheduleBlocks = blocks

        var list = tasks
        list[tIdx].isScheduled = false
        list[tIdx].scheduleBlockId = nil
        // 未排期任务不允许处于“执行中/暂停”语义上状态。
        if list[tIdx].status == .inProgress || list[tIdx].status == .paused {
            list[tIdx].status = .todo
            list[tIdx].completedAt = nil
        }
        list[tIdx].updatedAt = Date()
        tasks = list

        saveScheduleBlocks()
        saveTasks()

        notificationService.cancelNotifications(identifiers: reminderIds)
    }

    /// 一次 LLM 调用完成：当前日期未排期任务补全 + 自动排期落地。
    func scheduleCurrentDay() async {
        guard !isScheduling else { return }
        scheduleExecutionState = .scheduling

        guard canScheduleTask else {
            scheduleExecutionState = .failure("Scheduling is only available for today.")
            return
        }

        let provider = settings.selectedProvider
        guard !provider.models.isEmpty else {
            scheduleExecutionState = .failure(AIServiceError.providerNotSelected.userMessage)
            return
        }
        let apiKey = settings.trimmedAPIKeyForSelectedProvider()
        guard !apiKey.isEmpty else {
            scheduleExecutionState = .failure(
                "The API key for \"\(settings.selectedProvider.displayName)\" is empty. Add it in Settings first."
            )
            return
        }

        let modelId = settings.selectedModelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultModelId
            : settings.selectedModelId

        let calendar = Calendar.current
        let dayTasks = tasks.filter { calendar.isDate($0.taskDate, inSameDayAs: selectedDate) }
        let scheduledTasks = dayTasks.filter { sidebarBucket(for: $0) == .scheduled }
        let unscheduledTasks = dayTasks.filter { sidebarBucket(for: $0) == .unscheduled }

        guard !unscheduledTasks.isEmpty || !scheduledTasks.isEmpty else {
            scheduleExecutionState = .failure("No schedulable tasks for today.")
            return
        }
        guard !unscheduledTasks.isEmpty else {
            scheduleExecutionState = .failure("No unscheduled tasks to process.")
            return
        }

        do {
            let request = try makeSchedulingRequest(
                scheduledTasks: scheduledTasks,
                unscheduledTasks: unscheduledTasks
            )

            let response = try await taskSchedulingService.schedule(
                request: request,
                provider: provider,
                apiKey: apiKey,
                modelId: modelId
            )
            try applySchedulingResponse(
                response,
                dayTasks: dayTasks,
                selectedDayScheduledTasks: scheduledTasks,
                selectedDayUnscheduledTasks: unscheduledTasks
            )
            scheduleExecutionState = .success
        } catch let err as AIServiceError {
            record(err)
            scheduleExecutionState = .failure(err.userMessage)
        } catch let err as TaskSchedulingServiceError {
            record(err)
            scheduleExecutionState = .failure(err.localizedDescription)
        } catch {
            record(error)
            scheduleExecutionState = .failure("Scheduling failed. Please try again.")
        }
    }

    // MARK: - Settings

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveSettings()

        // 设置变更需要刷新“今天(taskDate)”的未来提醒（确保后续/已存在排期使用新配置）。
        Task { [weak self] in
            guard let self else { return }
            await self.refreshTaskRemindersForToday()
        }
    }

    // MARK: - Private — indices & ordering

    private func indexOfTask(id: UUID) -> Int? {
        tasks.firstIndex { $0.id == id }
    }

    /// 当前选中日、侧栏为 Scheduled 的其它任务中，排期块的最晚结束时间（不含 `excludingTaskId`）。
    private func latestScheduledBlockEndOnSelectedDay(excludingTaskId excludeId: UUID) -> Date? {
        var latest: Date?
        for block in scheduleBlocks {
            guard block.taskId != excludeId else { continue }
            guard let t = tasks.first(where: { $0.id == block.taskId }) else { continue }
            guard isTaskForSelectedDate(t) else { continue }
            guard Self.bucket(for: t, scheduleBlocks: scheduleBlocks) == .scheduled else { continue }
            if let cur = latest {
                if block.endAt > cur { latest = block.endAt }
            } else {
                latest = block.endAt
            }
        }
        return latest
    }

    private static func bucket(for task: ChronaTask, scheduleBlocks: [ScheduleBlock]) -> TaskBucket {
        if task.status == .done { return .completed }
        guard task.isScheduled, let bid = task.scheduleBlockId else { return .unscheduled }
        guard let block = scheduleBlocks.first(where: { $0.id == bid }), block.taskId == task.id else {
            return .unscheduled
        }
        return .scheduled
    }

    private func isTaskForSelectedDate(_ task: ChronaTask) -> Bool {
        Calendar.current.isDate(task.taskDate, inSameDayAs: selectedDate)
    }

    private func reconcileSelectionAfterLoad() {
        if let s = selection, tasks.contains(where: { $0.id == s && isTaskForSelectedDate($0) }) { return }
        selection = tasks(in: .unscheduled).first?.id
            ?? tasks(in: .scheduled).first?.id
            ?? tasks(in: .completed).first?.id
    }

    private func reconcileSelectionAfterDateChange() {
        if let s = selection, tasks.contains(where: { $0.id == s && isTaskForSelectedDate($0) }) { return }
        selection = tasks(in: .unscheduled).first?.id
            ?? tasks(in: .scheduled).first?.id
            ?? tasks(in: .completed).first?.id
    }

    // MARK: - Notifications (local, scheduled tasks only)

    private static let reminderIdentifierPrefix = "taskReminder-"

    private static func reminderIdentifier(for scheduleBlockId: UUID) -> String {
        "\(reminderIdentifierPrefix)\(scheduleBlockId.uuidString)"
    }

    private enum ReminderL10n {
        static var title: String {
            NSLocalizedString(
                "task_reminder_title",
                bundle: .main,
                value: "Task starting soon",
                comment: "Title for task reminder notifications"
            )
        }

        static func startsInMinutes(taskTitle: String, minutes: Int) -> String {
            let format = NSLocalizedString(
                "task_reminder_body_starts_in_minutes",
                bundle: .main,
                value: "%@ starts in %d minutes",
                comment: "Body for task reminder shown before task starts"
            )
            return String(format: format, taskTitle, minutes)
        }

        static func startsNow(taskTitle: String) -> String {
            let format = NSLocalizedString(
                "task_reminder_body_starts_now",
                bundle: .main,
                value: "Starting now: %@",
                comment: "Body for task reminder shown when task should start now"
            )
            return String(format: format, taskTitle)
        }
    }

    private func reminderIdentifiers(forTaskId taskId: UUID) -> [String] {
        scheduleBlocks
            .filter { $0.taskId == taskId }
            .map { Self.reminderIdentifier(for: $0.id) }
    }

    /// 调试入口：打印“当前会被创建”的任务提醒时间与文案（基于内存状态，不读取系统 pending 列表）。
    func debugPrintCurrentReminderPreview() {
        let now = Date()
        let formatter = Self.isoDateTimeFormatter
        let previews = currentReminderPreviews(now: now)

        print("=== Chrona Reminder Preview ===")
        print("now: \(formatter.string(from: now))")
        print("enabled: \(settings.taskReminderEnabled), minutesBefore: \(settings.reminderMinutesBefore)")
        guard settings.taskReminderEnabled, settings.reminderMinutesBefore >= 0 else {
            print("提醒已关闭或配置非法，当前不会创建任何提醒。")
            print("=== End Reminder Preview ===")
            return
        }
        guard !previews.isEmpty else {
            print("当前没有可创建的未来提醒。")
            print("=== End Reminder Preview ===")
            return
        }

        for item in previews {
            print("[\(item.identifier)] triggerAt=\(formatter.string(from: item.triggerAt)) title=\(item.title) body=\(item.body)")
        }
        print("=== End Reminder Preview ===")
    }

    private func scheduleTaskReminderIfNeeded(for block: ScheduleBlock) async {
        guard settings.taskReminderEnabled, settings.reminderMinutesBefore >= 0 else { return }

        guard let task = tasks.first(where: { $0.id == block.taskId }) else { return }
        guard task.status != .inProgress, task.status != .done else { return }
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        guard Calendar.current.isDate(task.taskDate, inSameDayAs: todayStart) else { return }

        let triggerTime = block.startAt.addingTimeInterval(-Double(settings.reminderMinutesBefore * 60))
        guard triggerTime >= now else { return }
        let title = ReminderL10n.title
        let identifier = Self.reminderIdentifier(for: block.id)
        let granted = await notificationService.requestAuthorizationIfNeeded()
        guard granted else { return }

        // 关键：等待授权期间如果用户已“移出/删除排期”，本次异步创建必须被丢弃。
        let now2 = Date()
        let todayStart2 = Calendar.current.startOfDay(for: now2)
        guard let currentTask = tasks.first(where: { $0.id == block.taskId }) else { return }
        guard currentTask.status != .inProgress, currentTask.status != .done else { return }
        guard currentTask.isScheduled, currentTask.scheduleBlockId == block.id else { return }
        guard scheduleBlocks.contains(where: { $0.id == block.id && $0.taskId == block.taskId }) else { return }
        guard Calendar.current.isDate(currentTask.taskDate, inSameDayAs: todayStart2) else { return }
        let triggerTime2 = block.startAt.addingTimeInterval(-Double(settings.reminderMinutesBefore * 60))
        guard triggerTime2 >= now2 else { return }

        let reminderLeadMinutes = max(0, settings.reminderMinutesBefore)
        let body2: String
        if reminderLeadMinutes > 0 {
            body2 = ReminderL10n.startsInMinutes(taskTitle: currentTask.title, minutes: reminderLeadMinutes)
        } else {
            body2 = ReminderL10n.startsNow(taskTitle: currentTask.title)
        }

        await notificationService.scheduleNotification(
            identifier: identifier,
            title: title,
            body: body2,
            triggerAt: triggerTime2
        )
    }

    private func currentReminderPreviews(now: Date) -> [(identifier: String, title: String, body: String, triggerAt: Date)] {
        let todayStart = Calendar.current.startOfDay(for: now)
        let tasksById = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var previews: [(identifier: String, title: String, body: String, triggerAt: Date)] = []

        for block in scheduleBlocks {
            guard let task = tasksById[block.taskId] else { continue }
            guard task.isScheduled, task.scheduleBlockId == block.id else { continue }
            guard task.status != .inProgress, task.status != .done else { continue }
            guard Calendar.current.isDate(task.taskDate, inSameDayAs: todayStart) else { continue }

            let triggerAt = block.startAt.addingTimeInterval(-Double(settings.reminderMinutesBefore * 60))
            guard triggerAt >= now else { continue }

            let reminderLeadMinutes = max(0, settings.reminderMinutesBefore)
            let body: String
            if reminderLeadMinutes > 0 {
                body = ReminderL10n.startsInMinutes(taskTitle: task.title, minutes: reminderLeadMinutes)
            } else {
                body = ReminderL10n.startsNow(taskTitle: task.title)
            }

            previews.append((
                identifier: Self.reminderIdentifier(for: block.id),
                title: ReminderL10n.title,
                body: body,
                triggerAt: triggerAt
            ))
        }

        return previews.sorted { $0.triggerAt < $1.triggerAt }
    }

    /// 刷新“今天(taskDate)”的未来提醒：取消旧待触发通知并按新设置重建。
    private func refreshTaskRemindersForToday() async {
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)

        // 彻底清理本应用的任务提醒，避免重启/异常退出后残留 pending。
        await notificationService.cancelPendingNotifications(withIdentifierPrefix: Self.reminderIdentifierPrefix)

        // 只为任务归属到“今天”的排期块创建/更新提醒。
        let tasksById = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let relevantBlocks = scheduleBlocks.filter { block in
            guard let task = tasksById[block.taskId] else { return false }
            guard task.isScheduled, task.scheduleBlockId == block.id else { return false }
            guard task.status != .inProgress, task.status != .done else { return false }
            return Calendar.current.isDate(task.taskDate, inSameDayAs: todayStart)
        }

        guard settings.taskReminderEnabled, settings.reminderMinutesBefore >= 0 else { return }

        let futureBlocks = relevantBlocks.filter { block in
            let triggerTime = block.startAt.addingTimeInterval(-Double(settings.reminderMinutesBefore * 60))
            return triggerTime >= now
        }
        guard !futureBlocks.isEmpty else { return }

        let granted = await notificationService.requestAuthorizationIfNeeded()
        guard granted else { return }

        for block in futureBlocks {
            let triggerTime = block.startAt.addingTimeInterval(-Double(settings.reminderMinutesBefore * 60))
            guard triggerTime >= now else { continue }

            // 再次校验：避免并发情况下调度出“已移出/删除”的提醒。
            guard let task = tasks.first(where: { $0.id == block.taskId }) else { continue }
            guard task.status != .inProgress, task.status != .done else { continue }
            guard task.isScheduled, task.scheduleBlockId == block.id else { continue }
            guard Calendar.current.isDate(task.taskDate, inSameDayAs: todayStart) else { continue }
            guard scheduleBlocks.contains(where: { $0.id == block.id && $0.taskId == block.taskId }) else { continue }

            let reminderLeadMinutes = max(0, settings.reminderMinutesBefore)
            let title = ReminderL10n.title
            let body: String
            if reminderLeadMinutes > 0 {
                body = ReminderL10n.startsInMinutes(taskTitle: task.title, minutes: reminderLeadMinutes)
            } else {
                body = ReminderL10n.startsNow(taskTitle: task.title)
            }

            let identifier = Self.reminderIdentifier(for: block.id)
            await notificationService.scheduleNotification(
                identifier: identifier,
                title: title,
                body: body,
                triggerAt: triggerTime
            )
        }
    }

    private func nextSortOrder() -> Int {
        (tasks.map(\.sortOrder).max() ?? -1) + 1
    }

    private func isFixedTimeTask(taskId: UUID, in tasks: [ChronaTask]) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskId }) else { return false }
        let source = [task.userTimeHint ?? "", task.title]
            .joined(separator: " ")
            .lowercased()
        // 覆盖常见输入：14:00-15:00 / 14:00~15:00 / 14:00 to 15:00
        return source.range(of: #"\b([01]?\d|2[0-3]):[0-5]\d\s*([-~]|to)\s*([01]?\d|2[0-3]):[0-5]\d\b"#, options: .regularExpression) != nil
    }

    private func firstFixedAnchorStartAfter(date: Date, on day: Date, in blocks: [ScheduleBlock], tasks: [ChronaTask]) -> Date? {
        let dayBlocks = blocks
            .filter { Calendar.current.isDate($0.startAt, inSameDayAs: day) }
            .sorted { $0.startAt < $1.startAt }
        for block in dayBlocks where block.startAt >= date {
            if isFixedTimeTask(taskId: block.taskId, in: tasks) {
                return block.startAt
            }
        }
        return nil
    }

    private func areStrictlyContiguous(leftEnd: Date, rightStart: Date) -> Bool {
        abs(rightStart.timeIntervalSince(leftEnd)) < 1
    }

    // MARK: - Private — AI schedule flow

    private func makeSchedulingRequest(
        scheduledTasks: [ChronaTask],
        unscheduledTasks: [ChronaTask]
    ) throws -> SchedulingServiceRequest {
        let dateText = Self.dateOnlyFormatter.string(from: selectedDate)
        let currentTimeText = Self.isoDateTimeFormatter.string(from: Date())
        let scheduledPayload: [SchedulingServiceRequest.ScheduledTask] = scheduledTasks.compactMap { task in
            guard let block = scheduleBlock(forTaskId: task.id) else { return nil }
            return .init(
                taskId: task.id.uuidString,
                title: task.title,
                start: Self.isoDateTimeFormatter.string(from: block.startAt),
                end: Self.isoDateTimeFormatter.string(from: block.endAt),
                status: task.status.rawValue
            )
        }
        let unscheduledPayload: [SchedulingServiceRequest.UnscheduledTask] = unscheduledTasks.map { task in
            .init(
                taskId: task.id.uuidString,
                title: task.title,
                estimatedMinutes: task.estimatedMinutes,
                priority: task.priority.rawValue,
                userTimeHint: task.userTimeHint,
                status: task.status.rawValue,
                needsAnalysis: !hasTaskBeenAnalyzed(task)
            )
        }
        let workingHours = settings.workingHours.ranges
            .filter { $0.startMinutes < $0.endMinutes }
            .sorted { $0.startMinutes < $1.startMinutes }
            .map { range in
                SchedulingServiceRequest.WorkingHour(
                    start: Self.clockString(fromMinutes: range.startMinutes),
                    end: Self.clockString(fromMinutes: range.endMinutes)
                )
            }

        guard !workingHours.isEmpty else {
            throw ChronaStoreError.noWorkingHoursConfigured
        }

        return SchedulingServiceRequest(
            selectedDate: dateText,
            currentTime: currentTimeText,
            workingHours: workingHours,
            scheduledTasks: scheduledPayload,
            unscheduledTasks: unscheduledPayload
        )
    }

    private func applySchedulingResponse(
        _ response: SchedulingLLMResponse,
        dayTasks: [ChronaTask],
        selectedDayScheduledTasks: [ChronaTask],
        selectedDayUnscheduledTasks: [ChronaTask]
    ) throws {
        var tasksDraft = tasks
        var blocksDraft = scheduleBlocks
        let now = Date()
        let dayTaskIdSet = Set(dayTasks.map(\.id))
        let analysableTaskIdSet = Set(
            selectedDayUnscheduledTasks
                .filter { !hasTaskBeenAnalyzed($0) }
                .map(\.id)
        )

        let selectedDateText = Self.dateOnlyFormatter.string(from: selectedDate)
        let calendar = Calendar.current
        let allowedRanges = settings.workingHours.ranges
            .filter { $0.startMinutes < $0.endMinutes }
            .sorted { $0.startMinutes < $1.startMinutes }

        for update in response.taskUpdates {
            guard let taskId = UUID(uuidString: update.taskId),
                  let idx = tasksDraft.firstIndex(where: { $0.id == taskId }) else {
                throw TaskSchedulingServiceError.invalidTaskId(update.taskId)
            }
            guard analysableTaskIdSet.contains(taskId) else {
                // 任务已分析过：忽略模型重复分析结果，避免覆盖用户已确认信息。
                continue
            }
            guard let mappedPriority = ChronaTaskPriority(rawValue: update.priority) else {
                throw TaskSchedulingServiceError.invalidTaskPriority(update.priority)
            }
            if !tasksDraft[idx].isDurationUserEdited {
                tasksDraft[idx].estimatedMinutes = max(1, update.estimatedMinutes)
            }
            if !tasksDraft[idx].isPriorityUserEdited {
                tasksDraft[idx].priority = mappedPriority
            }
            let trimmedHint = update.timeHint.trimmingCharacters(in: .whitespacesAndNewlines)
            tasksDraft[idx].userTimeHint = trimmedHint.isEmpty ? nil : trimmedHint
            if !update.aiSuggestions.isEmpty {
                var existingClues = tasksDraft[idx].clues
                var existingSet = Set(existingClues.map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) })
                for suggestion in update.aiSuggestions {
                    let content = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !content.isEmpty else { continue }
                    guard !existingSet.contains(content) else { continue }
                    existingClues.append(
                        ChronaTaskClue(
                            content: content,
                            createdAt: now
                        )
                    )
                    existingSet.insert(content)
                }
                tasksDraft[idx].clues = existingClues
            }
            tasksDraft[idx].updatedAt = now
        }

        var scheduleItemByTaskId: [UUID: SchedulingLLMResponse.ScheduleResult.ScheduledItem] = [:]
        for item in response.scheduleResult.scheduled {
            guard let taskId = UUID(uuidString: item.taskId), dayTaskIdSet.contains(taskId) else {
                throw TaskSchedulingServiceError.invalidTaskId(item.taskId)
            }
            scheduleItemByTaskId[taskId] = item
        }

        let unscheduledFromResponseSet: Set<UUID> = Set(response.scheduleResult.unscheduled.compactMap { UUID(uuidString: $0.taskId) })

        var parsedScheduledWindows: [(taskId: UUID, start: Date, end: Date)] = []
        for (taskId, item) in scheduleItemByTaskId {
            guard let start = parseLLMDateTime(item.start),
                  let end = parseLLMDateTime(item.end),
                  start < end else {
                throw TaskSchedulingServiceError.invalidScheduleDate("\(item.start) ~ \(item.end)")
            }
            parsedScheduledWindows.append((taskId, start, end))
        }
        try ensureNoOverlap(windows: parsedScheduledWindows)

        let existingBlocksByTaskId: [UUID: ScheduleBlock] = Dictionary(
            uniqueKeysWithValues: blocksDraft
                .filter { dayTaskIdSet.contains($0.taskId) }
                .map { ($0.taskId, $0) }
        )

        for entry in parsedScheduledWindows {
            if let existing = existingBlocksByTaskId[entry.taskId] {
                if let idx = blocksDraft.firstIndex(where: { $0.id == existing.id }) {
                    blocksDraft[idx].startAt = entry.start
                    blocksDraft[idx].endAt = entry.end
                    blocksDraft[idx].source = .auto
                    blocksDraft[idx].updatedAt = now
                    if let tIdx = tasksDraft.firstIndex(where: { $0.id == entry.taskId }) {
                        tasksDraft[tIdx].isScheduled = true
                        tasksDraft[tIdx].scheduleBlockId = existing.id
                        tasksDraft[tIdx].updatedAt = now
                    }
                }
            } else {
                let newBlock = ScheduleBlock(
                    taskId: entry.taskId,
                    startAt: entry.start,
                    endAt: entry.end,
                    source: .auto,
                    createdAt: now,
                    updatedAt: now
                )
                blocksDraft.append(newBlock)
                if let tIdx = tasksDraft.firstIndex(where: { $0.id == entry.taskId }) {
                    tasksDraft[tIdx].isScheduled = true
                    tasksDraft[tIdx].scheduleBlockId = newBlock.id
                    tasksDraft[tIdx].updatedAt = now
                }
            }
        }

        let selectedDayScheduledSet = Set(selectedDayScheduledTasks.map(\.id))
        for taskId in selectedDayScheduledSet {
            guard scheduleItemByTaskId[taskId] == nil else { continue }
            guard unscheduledFromResponseSet.contains(taskId) else { continue }
            blocksDraft.removeAll { $0.taskId == taskId && dayTaskIdSet.contains($0.taskId) }
            if let tIdx = tasksDraft.firstIndex(where: { $0.id == taskId }) {
                tasksDraft[tIdx].isScheduled = false
                tasksDraft[tIdx].scheduleBlockId = nil
                if tasksDraft[tIdx].status == .inProgress || tasksDraft[tIdx].status == .paused {
                    tasksDraft[tIdx].status = .todo
                    tasksDraft[tIdx].completedAt = nil
                }
                tasksDraft[tIdx].updatedAt = now
            }
        }

        for taskId in unscheduledFromResponseSet {
            guard scheduleItemByTaskId[taskId] == nil else { continue }
            if let tIdx = tasksDraft.firstIndex(where: { $0.id == taskId && dayTaskIdSet.contains($0.id) }) {
                blocksDraft.removeAll { $0.taskId == taskId }
                tasksDraft[tIdx].isScheduled = false
                tasksDraft[tIdx].scheduleBlockId = nil
                if tasksDraft[tIdx].status == .inProgress || tasksDraft[tIdx].status == .paused {
                    tasksDraft[tIdx].status = .todo
                    tasksDraft[tIdx].completedAt = nil
                }
                tasksDraft[tIdx].updatedAt = now
            }
        }

        try storage.saveScheduleBlocks(blocksDraft)
        try storage.saveTasks(tasksDraft)
        tasks = tasksDraft
        scheduleBlocks = blocksDraft
        reconcileSelectionAfterDateChange()
        Task { [weak self] in
            guard let self else { return }
            await self.refreshTaskRemindersForToday()
        }
    }

    private func isInWorkingHours(start: Date, end: Date, allowedRanges: [WorkingTimeRange]) -> Bool {
        let cal = Calendar.current
        let startMinutes = cal.component(.hour, from: start) * 60 + cal.component(.minute, from: start)
        let endMinutes = cal.component(.hour, from: end) * 60 + cal.component(.minute, from: end)
        return allowedRanges.contains { range in
            startMinutes >= range.startMinutes && endMinutes <= range.endMinutes
        }
    }

    private func ensureNoOverlap(windows: [(taskId: UUID, start: Date, end: Date)]) throws {
        let sorted = windows.sorted { $0.start < $1.start }
        guard sorted.count > 1 else { return }
        for idx in 1..<sorted.count where sorted[idx].start < sorted[idx - 1].end {
            throw TaskSchedulingServiceError.invalidResponseSchema
        }
    }

    private static func clockString(fromMinutes minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func parseLLMDateTime(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let parsed = Self.iso8601FormatterWithFractionalSeconds.date(from: trimmed) {
            return parsed
        }
        if let parsed = Self.iso8601Formatter.date(from: trimmed) {
            return parsed
        }
        return Self.isoDateTimeFormatter.date(from: trimmed)
    }

    private func hasTaskBeenAnalyzed(_ task: ChronaTask) -> Bool {
        if task.estimatedMinutes != nil { return true }
        if let hint = task.userTimeHint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            return true
        }
        return !task.clues.isEmpty
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let iso8601FormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// 将模型可能返回的 Markdown 轻量归一化为纯文本，避免 UI 文本视图展示 raw 语法。
    private static func normalizeSummaryPlainText(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let normalized = lines.map { line -> String in
            var s = line.trimmingCharacters(in: .whitespaces)

            if s.hasPrefix("### ") { s = String(s.dropFirst(4)) }
            else if s.hasPrefix("## ") { s = String(s.dropFirst(3)) }
            else if s.hasPrefix("# ") { s = String(s.dropFirst(2)) }

            if s.hasPrefix("- ") || s.hasPrefix("* ") {
                s = "• " + s.dropFirst(2)
            }

            let orderedPrefixRegex = #"^\d+\.\s+"#
            if let range = s.range(of: orderedPrefixRegex, options: .regularExpression) {
                s.removeSubrange(range)
            }
            return s
        }
        text = normalized.joined(separator: "\n")

        // 将常见 Markdown 强调符去掉，保留文本内容。
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        return text
    }

    // MARK: - Private — persistence

    private func saveTasks() {
        do {
            try storage.saveTasks(tasks)
        } catch {
            record(error)
        }
    }

    private func saveScheduleBlocks() {
        do {
            try storage.saveScheduleBlocks(scheduleBlocks)
        } catch {
            record(error)
        }
    }

    private func saveSettings() {
        do {
            try storage.saveSettings(settings)
        } catch {
            record(error)
        }
    }

    private func persistNormalizedData() {
        do {
            try storage.saveTasks(tasks)
            try storage.saveScheduleBlocks(scheduleBlocks)
        } catch {
            record(error)
        }
    }

    // MARK: - Private — normalization (load / invariants)

    /// 统一维护 `ChronaTaskStatus` 与 `completedAt`、任务与 `ScheduleBlock` 的对应关系。
    /// - Returns: 是否修改了内存中的 tasks / scheduleBlocks（需写回磁盘）。
    private func normalizeLoadedTasksAndBlocks() -> Bool {
        var changed = false

        var blocks = scheduleBlocks
        let taskIds = Set(tasks.map(\.id))

        let beforeBlockCount = blocks.count
        blocks.removeAll { !taskIds.contains($0.taskId) }
        if blocks.count != beforeBlockCount { changed = true }

        // 每个 taskId 仅保留一个块（取 updatedAt 最新的）。
        var bestByTask: [UUID: ScheduleBlock] = [:]
        for b in blocks {
            if let existing = bestByTask[b.taskId] {
                changed = true
                bestByTask[b.taskId] = b.updatedAt >= existing.updatedAt ? b : existing
            } else {
                bestByTask[b.taskId] = b
            }
        }
        let deduped = Array(bestByTask.values)
        if deduped.count != blocks.count { changed = true }
        blocks = deduped

        let blockByTaskId = Dictionary(uniqueKeysWithValues: blocks.map { ($0.taskId, $0) })

        var newTasks = tasks
        for i in newTasks.indices {
            if newTasks[i].status == .done {
                if newTasks[i].completedAt == nil {
                    newTasks[i].completedAt = newTasks[i].updatedAt
                    changed = true
                }
            } else if newTasks[i].completedAt != nil {
                newTasks[i].completedAt = nil
                changed = true
            }
        }

        for i in newTasks.indices {
            let tid = newTasks[i].id
            if let block = blockByTaskId[tid] {
                if newTasks[i].scheduleBlockId != block.id || !newTasks[i].isScheduled {
                    newTasks[i].scheduleBlockId = block.id
                    newTasks[i].isScheduled = true
                    changed = true
                }
            } else if newTasks[i].scheduleBlockId != nil || newTasks[i].isScheduled {
                newTasks[i].scheduleBlockId = nil
                newTasks[i].isScheduled = false
                changed = true
            }
        }

        tasks = newTasks
        scheduleBlocks = blocks
        return changed
    }
}

enum TodaySummaryState: Equatable {
    case idle
    case loadingSavedSummary
    case generating
    case streaming
    case success
    case failure(String)

    static func == (lhs: TodaySummaryState, rhs: TodaySummaryState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loadingSavedSummary, .loadingSavedSummary),
             (.generating, .generating),
             (.streaming, .streaming),
             (.success, .success):
            return true
        case (.failure(let l), .failure(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Store errors

enum ChronaStoreError: LocalizedError {
    case invalidScheduleRange
    case noWorkingHoursConfigured

    var errorDescription: String? {
        switch self {
        case .invalidScheduleRange:
            return "The scheduled end time must be after the start time."
        case .noWorkingHoursConfigured:
            return "No valid working hours are configured. Add them in Settings first."
        }
    }
}

enum ScheduleExecutionState: Equatable {
    case idle
    case scheduling
    case success
    case failure(String)
}
