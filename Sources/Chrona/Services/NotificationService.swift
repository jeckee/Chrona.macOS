import Foundation
import UserNotifications

final class NotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()

    private var authorizationTask: Task<Bool, Never>?

    func requestAuthorizationIfNeeded() async -> Bool {
        if let task = authorizationTask {
            return await task.value
        }

        authorizationTask = Task { [center] in
            let status = await withCheckedContinuation { cont in
                center.getNotificationSettings { settings in
                    cont.resume(returning: settings.authorizationStatus)
                }
            }

            switch status {
            case .authorized:
                return true
            case .denied:
                return false
            case .notDetermined, .provisional:
                // 仅在首次（notDetermined）时真正触发弹窗；其余状态（provisional）按可用处理。
                if status == .notDetermined {
                    let granted = await withCheckedContinuation { cont in
                        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                            cont.resume(returning: granted)
                        }
                    }
                    return granted
                }
                return status == .provisional
            @unknown default:
                return false
            }
        }

        return await authorizationTask!.value
    }

    func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        triggerAt: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        await withCheckedContinuation { cont in
            center.add(request) { _ in
                cont.resume()
            }
        }
    }

    func cancelNotifications(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelPendingNotifications(withIdentifierPrefix prefix: String) async {
        let requests: [UNNotificationRequest] = await withCheckedContinuation { cont in
            center.getPendingNotificationRequests { reqs in
                cont.resume(returning: reqs)
            }
        }

        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        cancelNotifications(identifiers: identifiers)
    }
}

