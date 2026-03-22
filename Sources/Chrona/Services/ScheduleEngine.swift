import Foundation

enum ScheduleEngine {
    /// Packs scheduled tasks sequentially from `dayAnchor` (typically 09:00 today).
    static func repackScheduled(tasks: inout [ChronaTask], dayAnchor: Date) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: dayAnchor)
        guard var cursor = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) else { return }

        let scheduledIDs = tasks
            .filter { $0.bucket == .scheduled }
            .sorted { $0.order < $1.order }
            .map(\.id)

        for id in scheduledIDs {
            guard let idx = tasks.firstIndex(where: { $0.id == id }) else { continue }
            let minutes = tasks[idx].durationMinutes
            let start = cursor
            guard let end = cal.date(byAdding: .minute, value: minutes, to: start) else { continue }
            tasks[idx].scheduledStart = start
            tasks[idx].scheduledEnd = end
            tasks[idx].isConflict = false
            cursor = end
        }
    }

    static func detectConflicts(tasks: [ChronaTask]) -> Set<UUID> {
        let scheduled = tasks
            .filter { $0.bucket == .scheduled }
            .sorted { ($0.scheduledStart ?? .distantPast) < ($1.scheduledStart ?? .distantPast) }
        var conflicts: Set<UUID> = []
        for pair in scheduled.indices.dropLast().map({ ($0, $0 + 1) }) {
            let a = scheduled[pair.0]
            let b = scheduled[pair.1]
            guard let ae = a.scheduledEnd, let bs = b.scheduledStart else { continue }
            if ae > bs {
                conflicts.insert(a.id)
                conflicts.insert(b.id)
            }
        }
        return conflicts
    }

    static func applyConflictFlags(tasks: inout [ChronaTask]) {
        let conflicts = detectConflicts(tasks: tasks)
        for i in tasks.indices where tasks[i].bucket == .scheduled {
            tasks[i].isConflict = conflicts.contains(tasks[i].id)
        }
    }
}
