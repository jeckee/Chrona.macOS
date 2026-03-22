import Combine
import Foundation

@MainActor
final class ChronaSettingsStore: ObservableObject {
    @Published var selectedPane: ChronaSettingsPane = .aiModel

    @Published var provider: ChronaAIProvider = .uxPilot {
        didSet { syncModelWithProvider() }
    }

    @Published var model: String = "gpt-4o"
    @Published var apiKey: String = "sk-proj-abc…"
    @Published var apiKeyVisible = false
    @Published var connectionState: ChronaAPIConnectionState = .connected

    @Published var timeRanges: [ChronaWorkingTimeRange]

    @Published var taskReminderEnabled = true
    @Published var taskReminderLead: ChronaTaskReminderLead = .ten
    @Published var dailySummaryEnabled = true
    /// Time-of-day for daily summary (date part ignored).
    @Published var dailySummaryTime: Date

    private var testTask: Task<Void, Never>?

    init() {
        let cal = Calendar.current
        let now = Date()
        timeRanges = [
            ChronaWorkingTimeRange(
                start: cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now,
                end: cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
            ),
            ChronaWorkingTimeRange(
                start: cal.date(bySettingHour: 13, minute: 0, second: 0, of: now) ?? now,
                end: cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
            ),
        ]
        dailySummaryTime = cal.date(bySettingHour: 18, minute: 30, second: 0, of: now) ?? now
    }

    func syncModelWithProvider() {
        if let first = provider.models.first, !provider.models.contains(model) {
            model = first
        }
    }

    func runConnectionTest() {
        testTask?.cancel()
        connectionState = .testing
        testTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else { return }
            connectionState = .connected
        }
    }

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
}
