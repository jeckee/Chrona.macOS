import Foundation

// MARK: - TaskBucket

enum TaskBucket: String {
    case scheduled
    case unscheduled
    case completed
}

// MARK: - ChronaTaskStatus

enum ChronaTaskStatus: String, Codable, Equatable, CaseIterable {
    case todo
    case inProgress
    case paused
    case done

    var displayName: String {
        switch self {
        case .todo: return "Not Started"
        case .inProgress: return "In Progress"
        case .paused: return "Paused"
        case .done: return "Completed"
        }
    }
}

// MARK: - ChronaTaskPriority

enum ChronaTaskPriority: String, Codable, Equatable, CaseIterable {
    case low
    case medium
    case high
}

// MARK: - ChronaTaskClue

struct ChronaTaskClue: Codable, Equatable, Identifiable {
    var id: UUID
    var content: String
    var createdAt: Date

    init(id: UUID = UUID(), content: String, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - ChronaTask

struct ChronaTask: Codable, Equatable, Identifiable {
    var id: UUID
    /// 任务归属的计划日期（不等同于创建时间/完成时间/排期时间）
    /// 约定：建议保存为当天 `startOfDay`，但解码时也会做归一化。
    var taskDate: Date
    var title: String
    var note: String?
    var status: ChronaTaskStatus
    var priority: ChronaTaskPriority
    var isPriorityUserEdited: Bool
    var userTimeHint: String?
    var estimatedMinutes: Int?
    var isDurationUserEdited: Bool
    var isScheduled: Bool
    var scheduleBlockId: UUID?
    var conclusion: String?
    var clues: [ChronaTaskClue]
    var sortOrder: Int
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        taskDate: Date = Calendar.current.startOfDay(for: Date()),
        title: String,
        note: String? = nil,
        status: ChronaTaskStatus = .todo,
        priority: ChronaTaskPriority = .medium,
        isPriorityUserEdited: Bool = false,
        userTimeHint: String? = nil,
        estimatedMinutes: Int? = nil,
        isDurationUserEdited: Bool = false,
        isScheduled: Bool = false,
        scheduleBlockId: UUID? = nil,
        conclusion: String? = nil,
        clues: [ChronaTaskClue] = [],
        sortOrder: Int = 0,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskDate = Calendar.current.startOfDay(for: taskDate)
        self.title = title
        self.note = note
        self.status = status
        self.priority = priority
        self.isPriorityUserEdited = isPriorityUserEdited
        self.userTimeHint = userTimeHint
        self.estimatedMinutes = estimatedMinutes
        self.isDurationUserEdited = isDurationUserEdited
        self.isScheduled = isScheduled
        self.scheduleBlockId = scheduleBlockId
        self.conclusion = conclusion
        self.clues = clues
        self.sortOrder = sortOrder
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Codable (旧数据兼容)
    private enum CodingKeys: String, CodingKey {
        case id
        case taskDate
        case title
        case note
        case status
        case priority
        case isPriorityUserEdited
        case userTimeHint
        case estimatedMinutes
        case isDurationUserEdited
        case isScheduled
        case scheduleBlockId
        case conclusion
        case clues
        case sortOrder
        case completedAt
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.note = try c.decodeIfPresent(String.self, forKey: .note)
        self.status = try c.decode(ChronaTaskStatus.self, forKey: .status)
        self.priority = try c.decode(ChronaTaskPriority.self, forKey: .priority)
        self.isPriorityUserEdited = try c.decodeIfPresent(Bool.self, forKey: .isPriorityUserEdited) ?? false
        self.userTimeHint = try c.decodeIfPresent(String.self, forKey: .userTimeHint)
        self.estimatedMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        self.isDurationUserEdited = try c.decodeIfPresent(Bool.self, forKey: .isDurationUserEdited) ?? false
        self.isScheduled = try c.decode(Bool.self, forKey: .isScheduled)
        self.scheduleBlockId = try c.decodeIfPresent(UUID.self, forKey: .scheduleBlockId)
        self.conclusion = try c.decodeIfPresent(String.self, forKey: .conclusion)
        self.clues = (try? c.decode([ChronaTaskClue].self, forKey: .clues)) ?? []
        self.sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        self.completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)

        // 旧版本没有 taskDate：回退到 createdAt 的 startOfDay
        let decodedTaskDate = try c.decodeIfPresent(Date.self, forKey: .taskDate)
        let fallback = self.createdAt
        self.taskDate = Calendar.current.startOfDay(for: decodedTaskDate ?? fallback)
    }
}
