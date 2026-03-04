import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 今日进度
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
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("还没有生成今日计划")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // 操作按钮
            VStack(spacing: 8) {
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
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title.contains("Chrona") || $0.contentView != nil }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }

            Divider()

            // 菜单项
            VStack(spacing: 4) {
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
        .frame(width: 300)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
