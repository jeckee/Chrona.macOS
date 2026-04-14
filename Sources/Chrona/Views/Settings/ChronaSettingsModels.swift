import Foundation

enum ChronaSettingsPane: String, CaseIterable, Identifiable {
    case appearance
    case aiModel
    case workingHours
    case reminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return "Appearance"
        case .aiModel: return "AI Model"
        case .workingHours: return "Working Hours"
        case .reminders: return "Reminders"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance: return "circle.lefthalf.filled"
        case .aiModel: return "brain.head.profile"
        case .workingHours: return "clock"
        case .reminders: return "bell"
        }
    }
}

enum AIConnectionState: Equatable {
    case idle
    case testing
    case success(message: String)
    case failure(message: String)
}

extension AIConnectionState {
    var isTesting: Bool {
        if case .testing = self { return true }
        return false
    }
}

enum ChronaTaskReminderLead: String, CaseIterable, Identifiable {
    case zero = "Before 0 min"
    case five = "Before 5 min"
    case ten = "Before 10 min"
    case fifteen = "Before 15 min"
    case thirty = "Before 30 min"

    var id: String { rawValue }
}

struct ChronaWorkingTimeRange: Identifiable, Equatable {
    var id: UUID
    var start: Date
    var end: Date

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
}
