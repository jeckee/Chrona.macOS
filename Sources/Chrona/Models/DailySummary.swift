import Foundation

/// 每日 Summary 的持久化结构（仅保留同一天的最新版本）。
struct DailySummary: Codable, Equatable, Identifiable {
    var id: String { Self.idString(for: date) }

    /// 归一化为当天 `startOfDay`，避免同日判断偏差。
    var date: Date

    /// summary 文本（非 JSON）。
    var content: String

    /// 生成时间（用于调试/展示，可用于未来扩展）。
    var generatedAt: Date

    init(date: Date, content: String, generatedAt: Date = Date()) {
        self.date = Calendar.current.startOfDay(for: date)
        self.content = content
        self.generatedAt = generatedAt
    }

    private static func idString(for date: Date) -> String {
        let normalized = Calendar.current.startOfDay(for: date)
        return Self.isoDateOnlyFormatter.string(from: normalized)
    }

    private static let isoDateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

