import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 今日进度
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日进度")
                        .font(.headline)

                    if let plan = appState.todayPlan {
                        let completedCount = plan.planItems.filter { item in
                            appState.tasks.first(where: { $0.id == item.taskId })?.status == .done
                        }.count
                        let totalCount = plan.planItems.count

                        HStack {
                            ProgressView(value: Double(completedCount), total: Double(totalCount))
                                .progressViewStyle(.linear)

                            Text("\(completedCount)/\(totalCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("还没有生成今日计划")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !notificationManager.isAuthorized {
                    Spacer()
                    Button(action: {
                        notificationManager.openSettings()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.slash.fill")
                            Text("开启通知")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("通知权限未开启")
                }
            }

            Divider()

            // 任务列表
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("任务列表")
                        .font(.headline)
                    Spacer()
                    if !appState.tasks.isEmpty {
                        let completedCount = appState.tasks.filter { $0.status == .done }.count
                        Text("已完成 \(completedCount)/\(appState.tasks.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let plan = appState.todayPlan {
                        let totalCount = plan.planItems.count + plan.overflowTasks.count
                        Text("共 \(totalCount) 项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !appState.tasks.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(appState.tasks) { task in
                                let planItem = appState.todayPlan?.planItems.first(where: { $0.taskId == task.id })
                                let overflowTask = appState.todayPlan?.overflowTasks.first(where: { $0.taskId == task.id })
                                
                                HStack(spacing: 8) {
                                    Button(action: {
                                        appState.toggleTaskStatus(task)
                                    }) {
                                        Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(task.status == .done ? .green : .secondary)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .strikethrough(task.status == .done)
                                            .foregroundColor(task.status == .done ? .secondary : .primary)
                                        
                                        if let item = planItem {
                                            Text("\(formatTime(item.start)) - \(formatTime(item.end))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        } else if let overflow = overflowTask {
                                            Text("无法安排: \(overflow.reason)")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        } else if let fixedStart = task.fixedStart, let fixedEnd = task.fixedEnd {
                                            Text("固定时段: \(formatTime(fixedStart)) - \(formatTime(fixedEnd))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        if let estimateMin = task.estimateMin {
                                            Text("预计时长: \(estimateMin) 分钟")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        if task.raw != task.title {
                                            Text(task.raw)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if let item = planItem {
                                            appState.removePlanItemFromPlan(item)
                                        } else if let overflow = overflowTask {
                                            appState.removeOverflowTask(overflow)
                                        } else {
                                            appState.deleteTask(task)
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 500)
                } else if let plan = appState.todayPlan, !(plan.planItems.isEmpty && plan.overflowTasks.isEmpty) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(plan.planItems) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: appState.taskStatus(for: item.taskId) == .done ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(appState.taskStatus(for: item.taskId) == .done ? .green : .secondary)
                                        .font(.system(size: 14))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        Text("\(formatTime(item.start)) - \(formatTime(item.end))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }

                            ForEach(plan.overflowTasks, id: \.taskId) { overflow in
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(overflow.title ?? "未安排任务")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        Text("无法安排: \(overflow.reason)")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 500)
                } else {
                    Text("暂无任务内容，可先在主窗口添加任务或生成今日计划")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()

            // 操作按钮
            HStack(spacing: 12) {
                Button("生成今日计划") {
                    _Concurrency.Task {
                        await appState.generatePlan(userInput: "")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(appState.isGeneratingPlan)

                Button("生成今日总结") {
                    _Concurrency.Task {
                        await appState.generateSummary()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(appState.isGeneratingSummary || appState.todayPlan == nil)

                Button("打开主窗口") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }

            Divider()

            // 菜单项
            VStack(spacing: 8) {
                Button("设置") {
                    showSettings = true
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("退出 Chrona") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            appState.loadTodayPlan()
            appState.loadTasks()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
