import Foundation
import UserNotifications

// MARK: - Notification Manager
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    @Published var isAuthorized = false

    private override init() {
        super.init()
        center.delegate = self
        checkAuthorization()
    }

    // MARK: - Authorization
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }

    func checkAuthorization() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Schedule Notifications
    func scheduleNotifications(for planItems: [PlanItem]) {
        let settings = SettingsManager.shared

        for item in planItems {
            // 开始前提醒
            let startNotificationDate = item.start.addingTimeInterval(-Double(settings.notifyLeadMinutes * 60))
            scheduleNotification(
                id: "start-\(item.id.uuidString)",
                title: "开始任务",
                body: item.title,
                date: startNotificationDate
            )
        }
    }

    private func scheduleNotification(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("通知调度失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancel Notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    func cancelNotifications(for planItems: [PlanItem]) {
        let identifiers = planItems.flatMap { item in
            ["start-\(item.id.uuidString)"]
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
