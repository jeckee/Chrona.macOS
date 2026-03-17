import SwiftUI

// MARK: - Task Row
struct TaskRow: View {
    @EnvironmentObject var appState: AppState
    let task: Task
    @State private var showTaskDetail = false

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
                showTaskDetail = true
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

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
        .sheet(isPresented: $showTaskDetail) {
            TaskDetailView(task: task)
                .environmentObject(appState)
        }
    }
}

// MARK: - Plan Item Card
struct PlanItemCard: View {
    @EnvironmentObject var appState: AppState
    let item: PlanItem
    @State private var showTaskDetail = false

    private var isCompleted: Bool {
        appState.taskStatus(for: item.taskId) == .done
    }

    private var task: Task? {
        appState.tasks.first(where: { $0.id == item.taskId })
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .secondary : .primary)

                    // 优先级信息（如果有）
                    if let priority = task?.priority {
                        HStack(spacing: 6) {
                            Text("优先级")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(priority.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(priorityColor(priority).opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                if item.locked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                }

                Button(action: {
                    if let task = task {
                        showTaskDetail = true
                    }
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Button(action: {
                    appState.removePlanItemFromPlan(item)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Menu {
                    Button("上移", systemImage: "arrow.up") {
                        appState.movePlanItemUp(item)
                    }
                    Button("下移", systemImage: "arrow.down") {
                        appState.movePlanItemDown(item)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }

            HStack {
                Image(systemName: "clock")
                    .font(.subheadline)
                Text("\(formatTime(item.start)) - \(formatTime(item.end))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(duration(from: item.start, to: item.end)) 分钟")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showTaskDetail) {
            if let task = task {
                TaskDetailView(task: task)
                    .environmentObject(appState)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func duration(from start: Date, to end: Date) -> Int {
        Int(end.timeIntervalSince(start) / 60)
    }

    private func priorityColor(_ priority: Task.TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Task Detail View
struct TaskDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Text("任务详情")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 任务信息
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("任务名称:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(task.title)
                        .font(.headline)
                }

                if let priority = task.priority {
                    HStack {
                        Text("优先级:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(priority.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(priorityColor(priority).opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                if let estimateMin = task.estimateMin {
                    HStack {
                        Text("预计时长:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(estimateMin) 分钟")
                            .font(.subheadline)
                    }
                }

                HStack {
                    Text("状态:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(task.status == .done ? "已完成" : "待完成")
                        .font(.subheadline)
                        .foregroundColor(task.status == .done ? .green : .orange)
                }

                if task.raw != task.title {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("原始描述:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(task.raw)
                            .font(.subheadline)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                }
            }

            Divider()

            // 获取线索按钮
            HStack {
                Button(action: {
                    _Concurrency.Task {
                        await appState.generateClues(for: task)
                    }
                }) {
                    HStack {
                        if appState.isGeneratingClues {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "lightbulb.fill")
                        }
                        Text(task.clues == nil ? "获取线索" : "重新获取线索")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isGeneratingClues)

                if appState.isGeneratingClues {
                    Text("AI 正在思考...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // 显示线索
            if let clues = task.clues {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("线索与资源:")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(clues)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
            } else if !appState.isGeneratingClues {
                Text("点击\"获取线索\"按钮，AI 将为您提供完成此任务的相关资源和建议。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }

            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
    }

    private func priorityColor(_ priority: Task.TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}
