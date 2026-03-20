import SwiftUI
import AppKit

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
                    if let plan = appState.todayPlan, !(plan.planItems.isEmpty && plan.overflowTasks.isEmpty) {
                        let totalCount = plan.planItems.count + plan.overflowTasks.count
                        Text("共 \(totalCount) 项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let plan = appState.todayPlan, !(plan.planItems.isEmpty && plan.overflowTasks.isEmpty) {
                    let taskById = Dictionary(uniqueKeysWithValues: appState.tasks.map { ($0.id, $0) })
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(plan.planItems) { item in
                                let status = taskById[item.taskId]?.status
                                HStack(spacing: 8) {
                                    Image(systemName: status == .done ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(status == .done ? .green : .secondary)
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
                    let menuWindow = NSApp.keyWindow
                    menuWindow?.orderOut(nil)
                    if !WindowManager.bringToFront(id: WindowIDs.main) {
                        openWindow(id: WindowIDs.main)
                        DispatchQueue.main.async {
                            _ = WindowManager.bringToFront(id: WindowIDs.main)
                        }
                    }
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
        MenuBarView.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
