import Foundation

// MARK: - ScheduleSource

enum ScheduleSource: String, Codable, Equatable {
    case manual
    case auto
}

// MARK: - ScheduleBlock

struct ScheduleBlock: Codable, Equatable, Identifiable {
    var id: UUID
    var taskId: UUID
    var startAt: Date
    var endAt: Date
    var source: ScheduleSource
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        taskId: UUID,
        startAt: Date,
        endAt: Date,
        source: ScheduleSource = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.startAt = startAt
        self.endAt = endAt
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var durationMinutes: Int {
        max(0, Int(endAt.timeIntervalSince(startAt) / 60))
    }
}
