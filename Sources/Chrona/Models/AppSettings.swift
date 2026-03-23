import Foundation

// MARK: - WorkingTimeRange

/// 每日工作时间模板中的一个时间段，用分钟数表示（0 = 00:00, 540 = 09:00, 1080 = 18:00）。
struct WorkingTimeRange: Codable, Equatable, Identifiable {
    var id: UUID
    var startMinutes: Int
    var endMinutes: Int

    init(id: UUID = UUID(), startMinutes: Int, endMinutes: Int) {
        self.id = id
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    var startFormatted: String {
        Self.format(minutes: startMinutes)
    }

    var endFormatted: String {
        Self.format(minutes: endMinutes)
    }

    private static func format(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - WorkingHoursSetting

struct WorkingHoursSetting: Codable, Equatable {
    var ranges: [WorkingTimeRange]

    init(ranges: [WorkingTimeRange] = []) {
        self.ranges = ranges
    }

    static let `default` = WorkingHoursSetting(ranges: [
        WorkingTimeRange(startMinutes: 540, endMinutes: 720),
        WorkingTimeRange(startMinutes: 780, endMinutes: 1080),
    ])
}

// MARK: - AppSettings

struct AppSettings: Equatable {
    var selectedProvider: AIProvider
    var selectedModelId: String
    var apiKey: String
    var workingHours: WorkingHoursSetting
    var reminderMinutesBefore: Int
    var taskReminderEnabled: Bool
    var dailySummaryEnabled: Bool
    /// 每日总结时间，用距午夜分钟数表示（与 workingHours 保持一致）。
    var dailySummaryTimeMinutes: Int

    init(
        selectedProvider: AIProvider = .qwen,
        selectedModelId: String = AIProvider.qwen.defaultModelId,
        apiKey: String = "",
        workingHours: WorkingHoursSetting = .default,
        reminderMinutesBefore: Int = 10,
        taskReminderEnabled: Bool = true,
        dailySummaryEnabled: Bool = true,
        dailySummaryTimeMinutes: Int = 1110 // 18:30
    ) {
        self.selectedProvider = selectedProvider
        self.selectedModelId = selectedModelId
        self.apiKey = apiKey
        self.workingHours = workingHours
        self.reminderMinutesBefore = reminderMinutesBefore
        self.taskReminderEnabled = taskReminderEnabled
        self.dailySummaryEnabled = dailySummaryEnabled
        self.dailySummaryTimeMinutes = dailySummaryTimeMinutes
    }

    static let `default` = AppSettings()
}

// MARK: - AppSettings + Codable (向后兼容)

extension AppSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case selectedProvider
        case selectedProviderId // legacy
        case selectedModelId
        case apiKey
        case workingHours
        case reminderMinutesBefore
        case taskReminderEnabled
        case dailySummaryEnabled
        case dailySummaryTimeMinutes
    }

    /// 自定义解码：缺失字段时回退到默认值，确保旧版 settings.json 可正常读取。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        if let p = try? c.decode(AIProvider.self, forKey: .selectedProvider) {
            self.selectedProvider = p
        } else if let legacyId = try? c.decode(String.self, forKey: .selectedProviderId),
                  let mapped = AIProvider.fromLegacyProviderId(legacyId) {
            self.selectedProvider = mapped
        } else {
            self.selectedProvider = defaults.selectedProvider
        }

        self.selectedModelId = (try? c.decode(String.self, forKey: .selectedModelId)) ?? defaults.selectedModelId
        self.apiKey = (try? c.decode(String.self, forKey: .apiKey)) ?? defaults.apiKey
        self.workingHours = (try? c.decode(WorkingHoursSetting.self, forKey: .workingHours)) ?? defaults.workingHours
        self.reminderMinutesBefore = (try? c.decode(Int.self, forKey: .reminderMinutesBefore)) ?? defaults.reminderMinutesBefore
        self.taskReminderEnabled = (try? c.decode(Bool.self, forKey: .taskReminderEnabled)) ?? defaults.taskReminderEnabled
        self.dailySummaryEnabled = (try? c.decode(Bool.self, forKey: .dailySummaryEnabled)) ?? defaults.dailySummaryEnabled
        self.dailySummaryTimeMinutes = (try? c.decode(Int.self, forKey: .dailySummaryTimeMinutes)) ?? defaults.dailySummaryTimeMinutes
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(selectedProvider, forKey: .selectedProvider)
        // 同时写入 legacy 字段，保证旧版 settings.json 结构也能被部分逻辑识别（如存在）。
        switch selectedProvider {
        case .qwen:
            try c.encode("Alibaba DashScope (Qwen)", forKey: .selectedProviderId)
        case .deepseek:
            break
        }

        try c.encode(selectedModelId, forKey: .selectedModelId)
        try c.encode(apiKey, forKey: .apiKey)
        try c.encode(workingHours, forKey: .workingHours)
        try c.encode(reminderMinutesBefore, forKey: .reminderMinutesBefore)
        try c.encode(taskReminderEnabled, forKey: .taskReminderEnabled)
        try c.encode(dailySummaryEnabled, forKey: .dailySummaryEnabled)
        try c.encode(dailySummaryTimeMinutes, forKey: .dailySummaryTimeMinutes)
    }
}
