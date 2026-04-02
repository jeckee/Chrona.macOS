import Combine
import Foundation

@MainActor
final class ChronaSettingsStore: ObservableObject {
    @Published var selectedPane: ChronaSettingsPane = .aiModel

    @Published var providerKeys: ProviderAPIKeys = ProviderAPIKeys()

    @Published var provider: AIProvider = .openai {
        willSet {
            guard !isSyncing else { return }
            providerKeys.setKey(apiKey, for: provider)
        }
        didSet {
            guard !isSyncing else { return }
            apiKey = providerKeys.key(for: provider)
            syncModelWithProvider()
        }
    }

    @Published var model: String = AppSettings.default.selectedModelId
    @Published var apiKey: String = ""
    @Published var apiKeyVisible = false
    @Published var connectionState: AIConnectionState = .idle

    @Published var timeRanges: [ChronaWorkingTimeRange] = []

    @Published var taskReminderEnabled: Bool = AppSettings.default.taskReminderEnabled
    @Published var taskReminderLead: ChronaTaskReminderLead = .ten

    /// Model 菜单：保留磁盘上存在但不在当前 Provider 列表中的模型 id。
    var modelPickerOptions: [String] {
        let base = provider.models
        if base.contains(model) { return base }
        return [model] + base
    }

    private weak var chronaStore: ChronaStore?
    /// 为 `true` 时 Combine sink 不写盘（reload / 初始化阶段）。
    private var isSyncing = false
    private var persistSink: AnyCancellable?
    private var testTask: Task<Void, Never>?

    init() {
        setupPersistPipeline()
    }

    // MARK: - Public — lifecycle

    func bind(chronaStore: ChronaStore) {
        self.chronaStore = chronaStore
    }

    /// 从 `ChronaStore.settings` 刷新可编辑 UI（每次打开设置窗口时调用）。
    func reloadFromChronaStore() {
        guard let chronaStore else { return }
        isSyncing = true
        applyAppSettingsToUI(chronaStore.settings)
        isSyncing = false
    }

    /// 关窗时调用，避免 debounce 未触发导致最后一次编辑未写入。
    func persistNowIfBound() {
        guard chronaStore != nil, !isSyncing else { return }
        pushToChronaStore()
    }

    // MARK: - Public — working hours

    func addTimeRange() {
        let cal = Calendar.current
        let base = Date()
        let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
        let end = cal.date(bySettingHour: 17, minute: 0, second: 0, of: base) ?? base
        timeRanges.append(ChronaWorkingTimeRange(start: start, end: end))
    }

    func removeTimeRange(id: UUID) {
        timeRanges.removeAll { $0.id == id }
    }

    func replaceTimeRange(id: UUID, start: Date? = nil, end: Date? = nil) {
        guard let idx = timeRanges.firstIndex(where: { $0.id == id }) else { return }
        var row = timeRanges[idx]
        if let start { row.start = start }
        if let end { row.end = end }
        var copy = timeRanges
        copy[idx] = row
        timeRanges = copy
    }

    // MARK: - Public — connection test

    func runConnectionTest() {
        testTask?.cancel()
        let currentProvider = provider
        let currentApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentApiKey.isEmpty else {
            connectionState = .failure(
                message: "The API key for \"\(currentProvider.displayName)\" is empty. Add it in Settings first."
            )
            return
        }

        connectionState = .testing

        testTask = Task.detached { [weak self] in
            guard let self else { return }

            do {
                let result = try await AIService.shared.testConnection(provider: currentProvider, apiKey: currentApiKey)
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.connectionState = .success(message: result)
                }
            } catch let err as AIServiceError {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.connectionState = .failure(message: err.userMessage)
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.connectionState = .failure(message: AIServiceError.unknown(underlying: error).userMessage)
                }
            }
        }
    }

    // MARK: - Private — Combine auto-persist

    private func setupPersistPipeline() {
        let triggers: [AnyPublisher<Void, Never>] = [
            $model.map { _ in () }.eraseToAnyPublisher(),
            $apiKey.map { _ in () }.eraseToAnyPublisher(),
            $providerKeys.map { _ in () }.eraseToAnyPublisher(),
            $provider.map { _ in () }.eraseToAnyPublisher(),
            $timeRanges.map { _ in () }.eraseToAnyPublisher(),
            $taskReminderLead.map { _ in () }.eraseToAnyPublisher(),
            $taskReminderEnabled.map { _ in () }.eraseToAnyPublisher(),
        ]
        persistSink = Publishers.MergeMany(triggers)
            .dropFirst(triggers.count)
            .debounce(for: .milliseconds(280), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self, !self.isSyncing else { return }
                self.pushToChronaStore()
            }
    }

    // MARK: - Private — sync helpers

    private func syncModelWithProvider() {
        if !provider.models.contains(model) {
            model = provider.models.first ?? model
        }
    }

    private func applyAppSettingsToUI(_ app: AppSettings) {
        model = app.selectedModelId
        providerKeys = app.providerAPIKeys
        provider = app.selectedProvider
        apiKey = providerKeys.key(for: app.selectedProvider)
        timeRanges = app.workingHours.ranges.map {
            ChronaWorkingTimeRange(
                id: $0.id,
                start: Self.dateForToday(minutes: $0.startMinutes),
                end: Self.dateForToday(minutes: $0.endMinutes)
            )
        }
        taskReminderLead = Self.reminderLead(for: app.reminderMinutesBefore)
        taskReminderEnabled = app.taskReminderEnabled

        // reloadFromChronaStore() 会在 isSyncing = true 下运行 provider 的 didSet，
        // 所以这里手动保证 model 与 provider 的默认映射一致。
        syncModelWithProvider()
    }

    private func pushToChronaStore() {
        guard let chronaStore else { return }
        let newSettings = makeAppSettings()
        guard newSettings != chronaStore.settings else { return }
        chronaStore.updateSettings(newSettings)
    }

    private func makeAppSettings() -> AppSettings {
        let ranges = timeRanges.map {
            WorkingTimeRange(
                id: $0.id,
                startMinutes: Self.minutesSinceMidnight(from: $0.start),
                endMinutes: Self.minutesSinceMidnight(from: $0.end)
            )
        }
        var keys = providerKeys
        keys.setKey(apiKey, for: provider)
        return AppSettings(
            selectedProvider: provider,
            selectedModelId: model,
            providerAPIKeys: keys,
            workingHours: WorkingHoursSetting(ranges: ranges),
            reminderMinutesBefore: Self.reminderMinutes(from: taskReminderLead),
            taskReminderEnabled: taskReminderEnabled
        )
    }

    // MARK: - Private — time conversion

    private static func minutesSinceMidnight(from date: Date) -> Int {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return h * 60 + m
    }

    private static func dateForToday(minutes: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        let h = minutes / 60
        let m = minutes % 60
        return cal.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now
    }

    // MARK: - Private — reminder lead mapping

    private static func reminderLead(for minutes: Int) -> ChronaTaskReminderLead {
        let choices = [0, 5, 10, 15, 30]
        let closest = choices.min(by: { abs($0 - minutes) < abs($1 - minutes) }) ?? 10
        switch closest {
        case 0: return .zero
        case 5: return .five
        case 15: return .fifteen
        case 30: return .thirty
        default: return .ten
        }
    }

    private static func reminderMinutes(from lead: ChronaTaskReminderLead) -> Int {
        switch lead {
        case .zero: return 0
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .thirty: return 30
        }
    }
}
