import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @EnvironmentObject var appState: AppState
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // API Key 配置
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Qwen API Key")
                                .font(.headline)

                            HStack {
                                if showAPIKey {
                                    TextField("输入 API Key", text: $apiKey)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("输入 API Key", text: $apiKey)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Button(action: {
                                    showAPIKey.toggle()
                                }) {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.plain)
                            }

                            HStack {
                                if settings.hasAPIKey {
                                    Label("已配置", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                } else {
                                    Label("未配置", systemImage: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }

                                Spacer()

                                Button("保存") {
                                    settings.qwenAPIKey = apiKey
                                }
                                .disabled(apiKey.isEmpty)

                                if settings.hasAPIKey {
                                    Button("清除") {
                                        settings.qwenAPIKey = ""
                                        apiKey = ""
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                    }

                    // 工作时间段
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("工作时间段")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    settings.workingBlocks.append(WorkingBlock(start: "09:00", end: "10:00"))
                                    settings.saveWorkingBlocks()
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(settings.workingBlocks) { block in
                                WorkingBlockRow(block: block)
                            }
                        }
                        .padding()
                    }

                    // 提醒设置
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("提醒设置")
                                .font(.headline)

                            HStack {
                                Text("提前提醒")
                                Spacer()
                                TextField("", value: $settings.notifyLeadMinutes, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                Text("分钟")
                            }
                            .onChange(of: settings.notifyLeadMinutes) { _ in
                                appState.refreshTodayPlanNotifications()
                            }
                        }
                        .padding()
                    }

                    // 自动总结设置
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("自动总结")
                                .font(.headline)

                            Toggle("启用每日自动总结", isOn: $settings.autoSummaryEnabled)
                                .onChange(of: settings.autoSummaryEnabled) { _ in
                                    appState.resetAutoSummary()
                                }

                            if settings.autoSummaryEnabled {
                                HStack {
                                    Text("总结时间:")
                                    TextField("HH:mm", text: $settings.autoSummaryTime)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .onChange(of: settings.autoSummaryTime) { _ in
                                            appState.resetAutoSummary()
                                        }
                                    Text("(24小时制，例如: 20:00)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            apiKey = settings.qwenAPIKey
        }
    }
}

// MARK: - Working Block Row
struct WorkingBlockRow: View {
    @StateObject private var settings = SettingsManager.shared
    let block: WorkingBlock

    var body: some View {
        HStack {
            TextField("开始", text: binding(for: \.start))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

            Text("-")

            TextField("结束", text: binding(for: \.end))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

            Spacer()

            Button(action: {
                settings.workingBlocks.removeAll { $0.id == block.id }
                settings.saveWorkingBlocks()
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }

    private func binding(for keyPath: WritableKeyPath<WorkingBlock, String>) -> Binding<String> {
        Binding(
            get: {
                if let index = settings.workingBlocks.firstIndex(where: { $0.id == block.id }) {
                    return settings.workingBlocks[index][keyPath: keyPath]
                }
                return ""
            },
            set: { newValue in
                if let index = settings.workingBlocks.firstIndex(where: { $0.id == block.id }) {
                    settings.workingBlocks[index][keyPath: keyPath] = newValue
                    settings.saveWorkingBlocks()
                }
            }
        )
    }
}
