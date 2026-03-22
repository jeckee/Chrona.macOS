import Foundation

enum ChronaFormatters {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    static let weekdayMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    static func durationString(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    static func timeRange(start: Date?, end: Date?) -> String {
        guard let start, let end else { return "—" }
        return "\(time.string(from: start)) - \(time.string(from: end))"
    }
}
