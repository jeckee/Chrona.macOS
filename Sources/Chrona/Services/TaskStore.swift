import Foundation
import SwiftUI

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [ChronaTask] = []
    @Published var selection: ChronaTask.ID?

    init() {
        var initial = ChronaTask.sampleScheduled
        initial.append(ChronaTask.sampleUnscheduled)
        initial.append(
            ChronaTask(
                id: UUID(),
                bucket: .unscheduled,
                order: 1,
                title: "Draft weekly update",
                status: .notStarted,
                priority: .medium,
                projectName: "Internal",
                notes: "",
                suggestedActions: [
                    SuggestedAction(text: "List shipped items"),
                    SuggestedAction(text: "Call out risks and asks")
                ],
                estimatedMinutes: 20,
                scheduledStart: nil,
                scheduledEnd: nil,
                isConflict: false,
                completedAt: nil
            )
        )
        normalizeOrders(for: .scheduled, in: &initial)
        normalizeOrders(for: .unscheduled, in: &initial)
        normalizeOrders(for: .completed, in: &initial)
        ScheduleEngine.applyConflictFlags(tasks: &initial)
        tasks = initial
        selection = tasks.first?.id
    }

    var selectedTask: ChronaTask? {
        guard let selection else { return nil }
        return tasks.first { $0.id == selection }
    }

    func tasks(in bucket: TaskBucket) -> [ChronaTask] {
        tasks.filter { $0.bucket == bucket }.sorted { $0.order < $1.order }
    }

    func binding(for id: ChronaTask.ID) -> Binding<ChronaTask> {
        Binding(
            get: {
                self.tasks.first { $0.id == id } ?? ChronaTask(
                    id: id,
                    bucket: .unscheduled,
                    order: 0,
                    title: "",
                    status: .notStarted,
                    priority: .medium,
                    projectName: "",
                    notes: "",
                    suggestedActions: [],
                    estimatedMinutes: 30,
                    scheduledStart: nil,
                    scheduledEnd: nil,
                    isConflict: false,
                    completedAt: nil
                )
            },
            set: { newValue in
                if let idx = self.tasks.firstIndex(where: { $0.id == id }) {
                    var copy = self.tasks
                    copy[idx] = newValue
                    self.tasks = copy
                }
            }
        )
    }

    func addTaskFromQuickInput(_ raw: String) {
        guard let parsed = AIInputParser.parse(raw) else { return }
        var t = tasks
        let nextOrder = (t.filter { $0.bucket == .unscheduled }.map(\.order).max() ?? -1) + 1
        let task = ChronaTask(
            id: UUID(),
            bucket: .unscheduled,
            order: nextOrder,
            title: parsed.title,
            status: .notStarted,
            priority: .medium,
            projectName: "Workspace",
            notes: "",
            suggestedActions: defaultSuggestions(for: parsed.title),
            estimatedMinutes: parsed.estimatedMinutes,
            scheduledStart: nil,
            scheduledEnd: nil,
            isConflict: false,
            completedAt: nil
        )
        t.append(task)
        tasks = t
        selection = task.id
    }

    func autoSchedule(taskID: ChronaTask.ID) {
        var t = tasks
        guard let idx = t.firstIndex(where: { $0.id == taskID }) else { return }
        guard t[idx].bucket == .unscheduled else { return }

        let maxOrder = t
            .filter { $0.bucket == .scheduled && $0.id != taskID }
            .map(\.order)
            .max() ?? -1

        t[idx].bucket = .scheduled
        t[idx].order = maxOrder + 1
        t[idx].isConflict = false
        normalizeOrders(for: .unscheduled, in: &t)
        ScheduleEngine.repackScheduled(tasks: &t, dayAnchor: Date())
        ScheduleEngine.applyConflictFlags(tasks: &t)
        tasks = t
    }

    func autoFixConflict(taskID: ChronaTask.ID) {
        var t = tasks
        ScheduleEngine.repackScheduled(tasks: &t, dayAnchor: Date())
        ScheduleEngine.applyConflictFlags(tasks: &t)
        if let idx = t.firstIndex(where: { $0.id == taskID }) {
            t[idx].isConflict = false
        }
        tasks = t
    }

    /// 将已排程任务按当日时间轴重新打包（侧栏顶栏「Schedule」等入口）。
    func repackScheduledTimes() {
        var t = tasks
        ScheduleEngine.repackScheduled(tasks: &t, dayAnchor: Date())
        ScheduleEngine.applyConflictFlags(tasks: &t)
        tasks = t
    }

    func start(taskID: ChronaTask.ID) {
        var t = tasks
        if let sel = selection, sel != taskID, let sidx = t.firstIndex(where: { $0.id == sel }) {
            if t[sidx].status == .inProgress {
                t[sidx].status = .paused
            }
        }
        guard let idx = t.firstIndex(where: { $0.id == taskID }) else { return }
        guard t[idx].bucket != .completed else { return }
        t[idx].status = .inProgress
        tasks = t
    }

    func pause(taskID: ChronaTask.ID) {
        var t = tasks
        guard let idx = t.firstIndex(where: { $0.id == taskID }) else { return }
        if t[idx].status == .inProgress {
            t[idx].status = .paused
        }
        tasks = t
    }

    func resume(taskID: ChronaTask.ID) {
        start(taskID: taskID)
    }

    func complete(taskID: ChronaTask.ID) {
        var t = tasks
        guard let idx = t.firstIndex(where: { $0.id == taskID }) else { return }
        t[idx].status = .completed
        t[idx].bucket = .completed
        t[idx].completedAt = Date()
        t[idx].isConflict = false
        normalizeOrders(for: .scheduled, in: &t)
        normalizeOrders(for: .unscheduled, in: &t)
        normalizeOrders(for: .completed, in: &t)
        ScheduleEngine.repackScheduled(tasks: &t, dayAnchor: Date())
        ScheduleEngine.applyConflictFlags(tasks: &t)
        tasks = t
        if selection == taskID {
            selection = tasks(in: .scheduled).first?.id
                ?? tasks(in: .unscheduled).first?.id
                ?? tasks(in: .completed).first?.id
        }
    }

    func cancel(taskID: ChronaTask.ID) {
        var t = tasks
        guard let idx = t.firstIndex(where: { $0.id == taskID }) else { return }
        let wasScheduled = t[idx].bucket == .scheduled
        t.remove(at: idx)
        if wasScheduled {
            ScheduleEngine.repackScheduled(tasks: &t, dayAnchor: Date())
            ScheduleEngine.applyConflictFlags(tasks: &t)
        }
        tasks = t
        if selection == taskID {
            selection = tasks(in: .scheduled).first?.id
                ?? tasks(in: .unscheduled).first?.id
                ?? tasks(in: .completed).first?.id
        }
    }

    func reorderWithinBucket(_ bucket: TaskBucket, draggingId: ChronaTask.ID, before beforeId: ChronaTask.ID?) {
        var t = tasks
        var slice = t.filter { $0.bucket == bucket }.sorted { $0.order < $1.order }
        guard let from = slice.firstIndex(where: { $0.id == draggingId }) else { return }
        let item = slice.remove(at: from)
        if let beforeId {
            if let idx = slice.firstIndex(where: { $0.id == beforeId }) {
                slice.insert(item, at: idx)
            } else {
                slice.append(item)
            }
        } else {
            slice.append(item)
        }
        for (i, row) in slice.enumerated() {
            if let idx = t.firstIndex(where: { $0.id == row.id }) {
                t[idx].order = i
            }
        }
        if bucket == .scheduled {
            ScheduleEngine.repackScheduled(tasks: &t, dayAnchor: Date())
            ScheduleEngine.applyConflictFlags(tasks: &t)
        }
        tasks = t
    }

    func toggleSuggestedAction(taskID: ChronaTask.ID, actionID: SuggestedAction.ID) {
        var t = tasks
        guard let tidx = t.firstIndex(where: { $0.id == taskID }) else { return }
        guard let aidx = t[tidx].suggestedActions.firstIndex(where: { $0.id == actionID }) else { return }
        t[tidx].suggestedActions[aidx].isDone.toggle()
        tasks = t
    }

    private func normalizeOrders(for bucket: TaskBucket, in tasks: inout [ChronaTask]) {
        let ids = tasks.filter { $0.bucket == bucket }.sorted { $0.order < $1.order }.map(\.id)
        for (i, id) in ids.enumerated() {
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx].order = i
            }
        }
    }

    private func defaultSuggestions(for title: String) -> [SuggestedAction] {
        [
            SuggestedAction(text: "Clarify the definition of done for “\(title)”"),
            SuggestedAction(text: "Identify the first 15-minute step"),
            SuggestedAction(text: "Note blockers as you discover them")
        ]
    }
}
