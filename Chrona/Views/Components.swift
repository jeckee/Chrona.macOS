import SwiftUI

// MARK: - Task Row
struct TaskRow: View {
    @EnvironmentObject var appState: AppState
    let task: Task

    var body: some View {
        HStack {
            Button(action: {
                appState.toggleTaskStatus(task)
            }) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .strikethrough(task.status == .done)
                .foregroundColor(task.status == .done ? .secondary : .primary)

            Spacer()

            Button(action: {
                appState.deleteTask(task)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Plan Item Card
struct PlanItemCard: View {
    @EnvironmentObject var appState: AppState
    let item: PlanItem
    @State private var showTimeEditor = false
    @State private var editStart: Date = Date()
    @State private var editEnd: Date = Date()

    private var isCompleted: Bool {
        appState.taskStatus(for: item.taskId) == .done
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    appState.completePlanItem(item)
                }) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Text(item.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)

                Spacer()

                if item.locked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                }

                Button(action: {
                    appState.removePlanItemFromPlan(item)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Image(systemName: "clock")
                    .font(.subheadline)
                Text("\(formatTime(item.start)) - \(formatTime(item.end))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: {
                    editStart = item.start
                    editEnd = item.end
                    showTimeEditor = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(duration(from: item.start, to: item.end)) 分钟")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .popover(isPresented: $showTimeEditor, arrowEdge: .bottom) {
                PlanItemTimeEditorView(
                    item: item,
                    editStart: $editStart,
                    editEnd: $editEnd,
                    onSave: {
                        appState.updatePlanItemTime(item: item, newStart: editStart, newEnd: editEnd)
                        showTimeEditor = false
                    },
                    onCancel: { showTimeEditor = false }
                )
                .frame(width: 220)
                .padding()
            }

            if !item.tips.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("行动提示:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ForEach(item.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.subheadline)
                            Text(tip)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func duration(from start: Date, to end: Date) -> Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

// MARK: - Plan Item Time Editor (Popover)
struct PlanItemTimeEditorView: View {
    let item: PlanItem
    @Binding var editStart: Date
    @Binding var editEnd: Date
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("修改时间")
                .font(.headline)

            DatePicker("开始", selection: $editStart, displayedComponents: .hourAndMinute)
                .labelsHidden()
            DatePicker("结束", selection: $editEnd, displayedComponents: .hourAndMinute)
                .labelsHidden()

            if editStart >= editEnd {
                Text("结束时间须晚于开始时间")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(editStart >= editEnd)
            }
        }
    }
}
