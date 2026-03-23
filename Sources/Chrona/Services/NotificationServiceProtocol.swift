import Foundation

/// 本地通知服务：用于“已排期任务”的本地提醒调度。
/// 负责授权检查、通知创建/取消；避免在 Store/View 中直接散落 UserNotifications 细节。
protocol NotificationServiceProtocol {
    /// 在需要时请求通知权限（notDetermined 才会真正弹窗）。
    /// - Returns: 是否已授权可用。
    func requestAuthorizationIfNeeded() async -> Bool

    /// 创建/覆盖一条本地通知（identifier 由上层保证稳定唯一）。
    func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        triggerAt: Date
    ) async

    /// 取消待触发通知。
    func cancelNotifications(identifiers: [String])

    /// 取消待触发通知：按 identifier 前缀匹配。
    /// 用于“彻底刷新某类提醒”（避免重启/异常退出后遗留）。
    func cancelPendingNotifications(withIdentifierPrefix prefix: String) async
}

