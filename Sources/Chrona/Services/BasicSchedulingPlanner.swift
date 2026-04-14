import Foundation

/// 无 LLM 时的顺序填充排期：按优先级稳定排序，避开当日已有排期块（含固定时间段会议等锚点）。
enum BasicSchedulingPlanner {

    private static func priorityRank(_ priority: ChronaTaskPriority) -> Int {
        switch priority {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    /// `unscheduledInDisplayOrder`：与侧栏「未排期」一致顺序（如 `sortOrder`），用于同优先级稳定排序。
    static func sortedForBasicScheduling(_ unscheduledInDisplayOrder: [ChronaTask]) -> [ChronaTask] {
        let indexed = Array(unscheduledInDisplayOrder.enumerated())
        let sorted = indexed.sorted { lhs, rhs in
            let ra = priorityRank(lhs.element.priority)
            let rb = priorityRank(rhs.element.priority)
            if ra != rb { return ra < rb }
            return lhs.offset < rhs.offset
        }
        return sorted.map(\.element)
    }

    static func mergedOccupiedIntervals(_ intervals: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = []
        var current = sorted[0]
        for next in sorted.dropFirst() {
            if next.start < current.end {
                current.end = max(current.end, next.end)
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)
        return merged
    }

    /// 返回不占用 `occupied` 的最早起点（从 `cursor` 起），每个任务时长 `durationSeconds`。
    /// - Precondition: `occupied` 须已按 `start` 升序排列且不重叠（可用 `mergedOccupiedIntervals` 产出）。
    static func nextSlotStart(cursor: Date, durationSeconds: TimeInterval, occupied: [(start: Date, end: Date)]) -> Date {
        var c = cursor
        let maxIterations = 4096
        for _ in 0..<maxIterations {
            let slotEnd = c.addingTimeInterval(durationSeconds)
            var conflict: (start: Date, end: Date)?
            for o in occupied {
                if slotEnd <= o.start || c >= o.end { continue }
                conflict = o
                break
            }
            guard let block = conflict else { return c }
            c = block.end
        }
        return c
    }

    static func occupiedIntervalsFromBlocks(_ blocks: [ScheduleBlock]) -> [(start: Date, end: Date)] {
        blocks.map { (start: $0.startAt, end: $0.endAt) }
    }
}
