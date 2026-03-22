import Foundation

enum TaskBucket: String, CaseIterable, Identifiable {
    case scheduled
    case unscheduled
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .unscheduled: return "Unscheduled"
        case .completed: return "Completed"
        }
    }
}

enum TaskStatus: String, CaseIterable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case paused = "Paused"
    case completed = "Completed"
}

enum TaskPriority: String, CaseIterable {
    case low = "Low Priority"
    case medium = "Medium Priority"
    case high = "High Priority"
}

struct SuggestedAction: Identifiable, Equatable {
    let id: UUID
    var text: String
    var isDone: Bool

    init(id: UUID = UUID(), text: String, isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}

struct ChronaTask: Identifiable, Equatable {
    let id: UUID
    var bucket: TaskBucket
    /// Order within the bucket (lower = higher priority).
    var order: Int
    var title: String
    var status: TaskStatus
    var priority: TaskPriority
    var projectName: String
    var notes: String
    var suggestedActions: [SuggestedAction]
    var estimatedMinutes: Int?
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var isConflict: Bool
    var completedAt: Date?

    var durationMinutes: Int {
        if let s = scheduledStart, let e = scheduledEnd {
            max(1, Int(e.timeIntervalSince(s) / 60))
        } else if let est = estimatedMinutes {
            est
        } else {
            30
        }
    }

    static func == (lhs: ChronaTask, rhs: ChronaTask) -> Bool {
        lhs.id == rhs.id
    }
}

extension ChronaTask {
    static let sampleScheduled: [ChronaTask] = {
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let t1 = cal.date(byAdding: .hour, value: 9, to: day)!
        let t2 = cal.date(byAdding: .minute, value: 150, to: t1)!
        let t3 = cal.date(byAdding: .hour, value: 11, to: day)!
        let t4 = cal.date(byAdding: .hour, value: 12, to: day)!
        let t5 = cal.date(byAdding: .hour, value: 13, to: day)!
        let t6 = cal.date(byAdding: .hour, value: 14, to: day)!

        return [
            ChronaTask(
                id: UUID(),
                bucket: .scheduled,
                order: 0,
                title: "Design Dashboard UI",
                status: .inProgress,
                priority: .high,
                projectName: "Project Alpha",
                notes: "",
                suggestedActions: [
                    SuggestedAction(text: "Review the user flow diagrams from yesterday"),
                    SuggestedAction(text: "Set up color variables in Figma based on brand guidelines"),
                    SuggestedAction(text: "Draft initial layout for the navigation sidebar"),
                ],
                estimatedMinutes: nil,
                scheduledStart: t1,
                scheduledEnd: t2,
                isConflict: false,
                completedAt: nil
            ),
            ChronaTask(
                id: UUID(),
                bucket: .scheduled,
                order: 1,
                title: "Client Meeting sync",
                status: .notStarted,
                priority: .medium,
                projectName: "Project Alpha",
                notes: "",
                suggestedActions: [
                    SuggestedAction(text: "Prepare 3 talking points for scope changes"),
                    SuggestedAction(text: "Share agenda 10 minutes before start")
                ],
                estimatedMinutes: nil,
                scheduledStart: t3,
                scheduledEnd: t4,
                isConflict: true,
                completedAt: nil
            ),
            ChronaTask(
                id: UUID(),
                bucket: .scheduled,
                order: 2,
                title: "Review PRs",
                status: .notStarted,
                priority: .medium,
                projectName: "Platform",
                notes: "",
                suggestedActions: [
                    SuggestedAction(text: "Prioritize security-related PRs first"),
                    SuggestedAction(text: "Leave actionable review comments")
                ],
                estimatedMinutes: nil,
                scheduledStart: t5,
                scheduledEnd: t6,
                isConflict: false,
                completedAt: nil
            )
        ]
    }()

    static let sampleUnscheduled: ChronaTask = ChronaTask(
        id: UUID(),
        bucket: .unscheduled,
        order: 0,
        title: "Reply to emails",
        status: .notStarted,
        priority: .low,
        projectName: "Inbox",
        notes: "",
        suggestedActions: [
            SuggestedAction(text: "Batch similar replies"),
            SuggestedAction(text: "Archive threads that need no action")
        ],
        estimatedMinutes: 30,
        scheduledStart: nil,
        scheduledEnd: nil,
        isConflict: false,
        completedAt: nil
    )
}
