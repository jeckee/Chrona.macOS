import Foundation

enum TaskDurationOption: String, CaseIterable, Identifiable {
    case m15 = "15m"
    case m30 = "30m"
    case m45 = "45m"
    case h1 = "1h"
    case h1m30 = "1h30m"
    case h2 = "2h"

    var id: String { rawValue }

    var minutes: Int {
        switch self {
        case .m15: return 15
        case .m30: return 30
        case .m45: return 45
        case .h1: return 60
        case .h1m30: return 90
        case .h2: return 120
        }
    }

    static func from(minutes: Int?) -> TaskDurationOption? {
        guard let minutes else { return nil }
        return allCases.first(where: { $0.minutes == minutes })
    }
}
