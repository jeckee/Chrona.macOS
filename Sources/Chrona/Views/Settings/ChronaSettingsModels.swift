import Foundation

enum ChronaSettingsPane: String, CaseIterable, Identifiable {
    case aiModel
    case workingHours
    case reminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiModel: return "AI Model"
        case .workingHours: return "Working Hours"
        case .reminders: return "Reminders"
        }
    }

    var systemImage: String {
        switch self {
        case .aiModel: return "brain.head.profile"
        case .workingHours: return "clock"
        case .reminders: return "bell"
        }
    }
}

enum ChronaAIProvider: String, CaseIterable, Identifiable {
    case uxPilot = "UX Pilot AI"
    case openAI = "OpenAI"
    case anthropic = "Anthropic"

    var id: String { rawValue }

    var models: [String] {
        switch self {
        case .uxPilot: return ["gpt-4o", "gpt-4o-mini"]
        case .openAI: return ["gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .anthropic: return ["claude-3-5-sonnet", "claude-3-opus"]
        }
    }
}

enum ChronaAPIConnectionState: Equatable {
    case idle
    case testing
    case connected
    case failed
}

enum ChronaTaskReminderLead: String, CaseIterable, Identifiable {
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
