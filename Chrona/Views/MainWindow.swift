import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showPlanInputSheet = false

    var body: some View {
        // 主区域：今日计划（全屏凸显）
        VStack(alignment: .leading, spacing: 0) {
            // 今日计划标题区
            HStack {
                Text("今日计划")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            if appState.isGeneratingPlan {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("AI thinking...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let plan = appState.todayPlan, !plan.planItems.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(plan.planItems.enumerated()), id: \.element.id) { index, item in
                            PlanItemCard(item: item)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: plan.planItems.count)
                        }

                        if !plan.overflowTasks.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            Text("无法安排的任务")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            ForEach(plan.overflowTasks, id: \.taskId) { overflow in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(overflow.title ?? "未安排项")
                                        .font(.subheadline)
                                    Text("原因: \(overflow.reason)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("建议: \(overflow.suggestion)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        if let summary = appState.todaySummary {
                            Divider()
                                .padding(.vertical, 8)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("今日总结")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text(summary.text)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary)
                    Text("还没有生成今日计划")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("点击「生成今日计划」开始")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.regularMaterial)
        .toolbar {
            ToolbarItemGroup {
                Button("生成今日计划") {
                    showPlanInputSheet = true
                }
                .disabled(appState.isGeneratingPlan)

                Button("生成今日总结") {
                    _Concurrency.Task {
                        await appState.generateSummary()
                    }
                }
                .disabled(appState.isGeneratingSummary || appState.todayPlan == nil)

                Button("设置") {
                    showSettings = true
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPlanInputSheet) {
            PlanInputSheet(onGenerate: { userInput in
                _Concurrency.Task {
                    await appState.generatePlan(userInput: userInput)
                    await MainActor.run {
                        if appState.errorMessage == nil {
                            showPlanInputSheet = false
                        }
                    }
                }
            })
        }
        .alert("错误", isPresented: .constant(appState.errorMessage != nil)) {
            Button("确定") {
                appState.errorMessage = nil
            }
        } message: {
            if let error = appState.errorMessage {
                Text(error)
            }
        }
        .frame(minWidth: 560, minHeight: 500)
    }
}

// MARK: - 生成今日计划时的描述输入弹窗
struct PlanInputSheet: View {
    @EnvironmentObject var appState: AppState
    @State private var descriptionInput = ""
    @Environment(\.dismiss) var dismiss
    let onGenerate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("生成今日计划")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(appState.isGeneratingPlan)
            }

            Text("描述你今天想做的事或目标，留空则由 AI 根据工作日建议计划。")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $descriptionInput)
                .font(.system(size: 14))
                .frame(minHeight: 160)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .disabled(appState.isGeneratingPlan)

            // 预留固定高度，避免出现「生成中」时整块内容上移把标题顶掉
            Group {
                if appState.isGeneratingPlan {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("AI 正在生成计划…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minHeight: 44)

            HStack {
                Spacer()
                Button("生成") {
                    onGenerate(descriptionInput.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(appState.isGeneratingPlan)
            }
        }
        .padding(24)
        .frame(width: 440, height: 400)
    }
}
