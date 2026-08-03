import UserNotifications

/// 让本地通知在 App 前台时也以横幅形式展示，方便测试与提醒。
@MainActor
final class NotificationDelegate: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
