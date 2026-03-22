import Foundation

// MARK: - Task Model
struct Task: Identifiable, Codable {
    let id: UUID
    var raw: String
    var title: String
    var estimateMin: Int?
    var fixedStart: Date?
    var fixedEnd: Date?
    var priority: TaskPriority?
    var status: TaskStatus
    var startedAt: Date?
    var pausedAt: Date?
    var completedAt: Date?
    var conclusion: String?
    var clues: String? // AI 提供的线索和资源

    enum TaskStatus: String, Codable {
        case todo
        case inProgress
        case paused
        case done
    }

    enum TaskPriority: String, Codable {
        case high = "高"
        case medium = "中"
        case low = "低"
    }

    init(id: UUID = UUID(), raw: String, title: String? = nil, estimateMin: Int? = nil, fixedStart: Date? = nil, fixedEnd: Date? = nil, priority: TaskPriority? = nil, status: TaskStatus = .todo, startedAt: Date? = nil, pausedAt: Date? = nil, completedAt: Date? = nil, conclusion: String? = nil, clues: String? = nil) {
        self.id = id
        self.raw = raw
        self.title = title ?? raw
        self.estimateMin = estimateMin
        self.fixedStart = fixedStart
        self.fixedEnd = fixedEnd
        self.priority = priority
        self.status = status
        self.startedAt = startedAt
        self.pausedAt = pausedAt
        self.completedAt = completedAt
        self.conclusion = conclusion
        self.clues = clues
    }
}

// MARK: - PlanItem Model
struct PlanItem: Identifiable, Codable {
    let id: UUID
    var taskId: UUID
    var title: String
    var start: Date
    var end: Date
    var locked: Bool
    var tips: [String]

    init(id: UUID = UUID(), taskId: UUID, title: String, start: Date, end: Date, locked: Bool = false, tips: [String] = []) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.start = start
        self.end = end
        self.locked = locked
        self.tips = tips
    }
}

// MARK: - DaySummary Model
struct DaySummary: Codable {
    let date: Date
    var text: String

    init(date: Date, text: String) {
        self.date = date
        self.text = text
    }
}

// MARK: - DayPlan Model
struct DayPlan: Codable {
    let date: Date
    var planItems: [PlanItem]
    var overflowTasks: [OverflowTask]

    init(date: Date, planItems: [PlanItem] = [], overflowTasks: [OverflowTask] = []) {
        self.date = date
        self.planItems = planItems
        self.overflowTasks = overflowTasks
    }
}

// MARK: - OverflowTask Model
struct OverflowTask: Codable {
    let taskId: UUID
    var title: String?
    var reason: String
    var suggestion: String

    init(taskId: UUID, title: String? = nil, reason: String, suggestion: String) {
        self.taskId = taskId
        self.title = title
        self.reason = reason
        self.suggestion = suggestion
    }
}
