import Foundation

// MARK: - File Storage Manager
class FileStorageManager {
    static let shared = FileStorageManager()

    private let fileManager = FileManager.default
    private var storageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let chronaDir = appSupport.appendingPathComponent("Chrona")

        if !fileManager.fileExists(atPath: chronaDir.path) {
            try? fileManager.createDirectory(at: chronaDir, withIntermediateDirectories: true)
        }

        return chronaDir
    }

    private init() {}

    // MARK: - Tasks
    func saveTasks(_ tasks: [Task]) throws {
        let url = storageDirectory.appendingPathComponent("tasks.json")
        let data = try JSONEncoder().encode(tasks)
        try data.write(to: url)
    }

    func loadTasks() -> [Task] {
        let url = storageDirectory.appendingPathComponent("tasks.json")
        guard let data = try? Data(contentsOf: url),
              let tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }
        return tasks
    }

    // MARK: - Day Plan
    func saveDayPlan(_ plan: DayPlan, for date: Date) throws {
        let filename = "plan-\(dateString(from: date)).json"
        let url = storageDirectory.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(plan)
        try data.write(to: url)
    }

    func loadDayPlan(for date: Date) -> DayPlan? {
        let filename = "plan-\(dateString(from: date)).json"
        let url = storageDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let plan = try? JSONDecoder().decode(DayPlan.self, from: data) else {
            return nil
        }
        return plan
    }

    // MARK: - Day Summary
    func saveDaySummary(_ summary: DaySummary, for date: Date) throws {
        let filename = "summary-\(dateString(from: date)).json"
        let url = storageDirectory.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(summary)
        try data.write(to: url)
    }

    func loadDaySummary(for date: Date) -> DaySummary? {
        let filename = "summary-\(dateString(from: date)).json"
        let url = storageDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let summary = try? JSONDecoder().decode(DaySummary.self, from: data) else {
            return nil
        }
        return summary
    }

    // MARK: - Helper
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
