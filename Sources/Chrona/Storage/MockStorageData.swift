import Foundation

#if DEBUG

// MARK: - ChronaTask + Mock

extension ChronaTask {
    static let mockSamples: [ChronaTask] = {
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        return [
            ChronaTask(
                taskDate: todayStart,
                title: "阅读 SwiftUI 文档",
                status: .todo,
                priority: .high,
                estimatedMinutes: 45,
                sortOrder: 0,
                createdAt: now
            ),
            ChronaTask(
                taskDate: todayStart,
                title: "修复登录页 Bug",
                status: .inProgress,
                priority: .high,
                estimatedMinutes: 30,
                sortOrder: 1,
                createdAt: now
            ),
            ChronaTask(
                taskDate: todayStart,
                title: "整理会议纪要",
                status: .todo,
                priority: .medium,
                estimatedMinutes: 20,
                sortOrder: 2,
                createdAt: now
            ),
            ChronaTask(
                taskDate: todayStart,
                title: "Review PR #42",
                status: .paused,
                priority: .low,
                estimatedMinutes: 60,
                sortOrder: 3,
                createdAt: now
            ),
        ]
    }()
}

// MARK: - ScheduleBlock + Mock

extension ScheduleBlock {
    static func mockSamples(for tasks: [ChronaTask]) -> [ScheduleBlock] {
        guard tasks.count >= 2 else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start1 = cal.date(byAdding: .hour, value: 9, to: today)!
        let end1 = cal.date(byAdding: .minute, value: 45, to: start1)!
        let start2 = cal.date(byAdding: .hour, value: 10, to: today)!
        let end2 = cal.date(byAdding: .minute, value: 30, to: start2)!

        return [
            ScheduleBlock(taskId: tasks[0].id, startAt: start1, endAt: end1, source: .auto),
            ScheduleBlock(taskId: tasks[1].id, startAt: start2, endAt: end2, source: .manual),
        ]
    }
}

// MARK: - AppSettings + Mock

extension AppSettings {
    static let mockSample = AppSettings(
        selectedProvider: .qwen,
        selectedModelId: "qwen3.5-plus",
        apiKey: "sk-mock-key-for-testing",
        workingHours: .default,
        reminderMinutesBefore: 10
    )
}

// MARK: - LocalStorageService + Seed

extension LocalStorageService {
    /// 将 mock 数据写入本地文件，仅用于开发调试。
    func seedMockData() throws {
        let tasks = ChronaTask.mockSamples
        try saveTasks(tasks)
        try saveScheduleBlocks(ScheduleBlock.mockSamples(for: tasks))
        try saveSettings(.mockSample)
    }
}

#endif
