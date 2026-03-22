import SwiftUI

struct TaskRowReorderHooks: ViewModifier {
    @EnvironmentObject private var store: TaskStore
    let bucket: TaskBucket
    let task: ChronaTask

    func body(content: Content) -> some View {
        content
            .draggable(task.id.uuidString) {
                Text(task.title)
                    .font(ChronaTokens.Typography.label)
                    .foregroundStyle(ChronaTokens.Colors.text)
                    .chronaCard(fill: ChronaTokens.Colors.bgSoft)
            }
            .dropDestination(for: String.self) { items, _ in
                guard let first = items.first, let dragged = UUID(uuidString: first), dragged != task.id else {
                    return false
                }
                store.reorderWithinBucket(bucket, draggingId: dragged, before: task.id)
                return true
            } isTargeted: { _ in }
    }
}

extension View {
    func chronaReorderable(in bucket: TaskBucket, task: ChronaTask) -> some View {
        modifier(TaskRowReorderHooks(bucket: bucket, task: task))
    }
}
