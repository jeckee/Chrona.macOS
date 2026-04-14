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

// MARK: - ProviderAPIKeys

/// 各 Provider 的 API Key 分字段存储，持久化稳定、不共用一条全局 key。
struct ProviderAPIKeys: Equatable, Codable {
    var openAI: String
    var anthropic: String
    var google: String
    var openRouter: String
    var deepSeek: String

    init(
        openAI: String = "",
        anthropic: String = "",
        google: String = "",
        openRouter: String = "",
        deepSeek: String = ""
    ) {
        self.openAI = openAI
        self.anthropic = anthropic
        self.google = google
        self.openRouter = openRouter
        self.deepSeek = deepSeek
    }

    func key(for provider: AIProvider) -> String {
        switch provider {
        case .openai: return openAI
        case .anthropic: return anthropic
        case .google: return google
        case .openrouter: return openRouter
        case .deepseek: return deepSeek
        }
    }

    mutating func setKey(_ value: String, for provider: AIProvider) {
        switch provider {
        case .openai: openAI = value
        case .anthropic: anthropic = value
        case .google: google = value
        case .openrouter: openRouter = value
        case .deepseek: deepSeek = value
        }
    }

    /// 是否全部为空（用于从旧版单 key 迁移）。
    var isAllEmpty: Bool {
        openAI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && anthropic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && google.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && openRouter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && deepSeek.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - AppSettings

struct AppSettings: Equatable {
    var selectedProvider: AIProvider
    var selectedModelId: String
    var providerAPIKeys: ProviderAPIKeys
    var workingHours: WorkingHoursSetting
    var reminderMinutesBefore: Int
    var taskReminderEnabled: Bool

    init(
        selectedProvider: AIProvider = .openai,
        selectedModelId: String = AIProvider.openai.defaultModelId,
        providerAPIKeys: ProviderAPIKeys = ProviderAPIKeys(),
        workingHours: WorkingHoursSetting = .default,
        reminderMinutesBefore: Int = 10,
        taskReminderEnabled: Bool = true
    ) {
        self.selectedProvider = selectedProvider
        self.selectedModelId = selectedModelId
        self.providerAPIKeys = providerAPIKeys
        self.workingHours = workingHours
        self.reminderMinutesBefore = reminderMinutesBefore
        self.taskReminderEnabled = taskReminderEnabled
    }

    static let `default` = AppSettings()

    /// 当前选中 Provider 对应 key（已 trim）。
    func trimmedAPIKeyForSelectedProvider() -> String {
        providerAPIKeys.key(for: selectedProvider).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 是否具备调用 LLM 的条件：已选择可用的 Provider 且对应 API Key 非空。
    var isAIAvailable: Bool {
        let provider = selectedProvider
        guard !provider.models.isEmpty else { return false }
        return !trimmedAPIKeyForSelectedProvider().isEmpty
    }
}

// MARK: - AppSettings + Codable (向后兼容)

extension AppSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case selectedProvider
        case selectedProviderId
        case selectedModelId
        case apiKey
        case providerAPIKeys
        case workingHours
        case reminderMinutesBefore
        case taskReminderEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        if let p = try? c.decode(AIProvider.self, forKey: .selectedProvider) {
            self.selectedProvider = p
        } else if let legacyId = try? c.decode(String.self, forKey: .selectedProviderId),
                  let mapped = AIProvider.fromLegacySettingsProviderId(legacyId) {
            self.selectedProvider = mapped
        } else {
            self.selectedProvider = defaults.selectedProvider
        }

        self.selectedModelId = (try? c.decode(String.self, forKey: .selectedModelId)) ?? defaults.selectedModelId

        var keys = (try? c.decode(ProviderAPIKeys.self, forKey: .providerAPIKeys)) ?? ProviderAPIKeys()
        let legacyKey = (try? c.decode(String.self, forKey: .apiKey)) ?? ""

        if keys.isAllEmpty, !legacyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch selectedProvider {
            case .openai: keys.openAI = legacyKey
            case .anthropic: keys.anthropic = legacyKey
            case .google: keys.google = legacyKey
            case .openrouter: keys.openRouter = legacyKey
            case .deepseek: keys.deepSeek = legacyKey
            }
        }

        self.providerAPIKeys = keys
        self.workingHours = (try? c.decode(WorkingHoursSetting.self, forKey: .workingHours)) ?? defaults.workingHours
        self.reminderMinutesBefore = (try? c.decode(Int.self, forKey: .reminderMinutesBefore)) ?? defaults.reminderMinutesBefore
        self.taskReminderEnabled = (try? c.decode(Bool.self, forKey: .taskReminderEnabled)) ?? defaults.taskReminderEnabled
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(selectedProvider, forKey: .selectedProvider)
        try c.encode(selectedModelId, forKey: .selectedModelId)
        try c.encode(providerAPIKeys, forKey: .providerAPIKeys)
        try c.encode(workingHours, forKey: .workingHours)
        try c.encode(reminderMinutesBefore, forKey: .reminderMinutesBefore)
        try c.encode(taskReminderEnabled, forKey: .taskReminderEnabled)
    }
}

private extension AIProvider {
    /// 旧版 `selectedProviderId` 显示名。
    static func fromLegacySettingsProviderId(_ legacy: String) -> AIProvider? {
        switch legacy {
        case "Alibaba DashScope (Qwen)": return .openai
        default: return nil
        }
    }
}
