import Foundation
import UserNotifications

final class NotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()

    private var cachedAuthorization: Bool?
    private var authorizationTask: Task<Bool, Never>?

    func requestAuthorizationIfNeeded() async -> Bool {
        if let cached = cachedAuthorization, cached {
            return true
        }

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

        let result = await authorizationTask!.value
        authorizationTask = nil
        if result {
            cachedAuthorization = true
        }
        return result
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

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerAt)
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
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func cancelPendingNotifications(withIdentifierPrefix prefix: String) async {
        let pendingRequests: [UNNotificationRequest] = await withCheckedContinuation { cont in
            center.getPendingNotificationRequests { reqs in
                cont.resume(returning: reqs)
            }
        }
        let deliveredNotifications: [UNNotification] = await withCheckedContinuation { cont in
            center.getDeliveredNotifications { notifications in
                cont.resume(returning: notifications)
            }
        }

        let pendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        let deliveredIdentifiers = deliveredNotifications
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(prefix) }
        let identifiers = Array(Set(pendingIdentifiers + deliveredIdentifiers))

        cancelNotifications(identifiers: identifiers)
    }
}

