import Foundation
import OpenLedgerCore
import UserNotifications

@MainActor
enum SubscriptionService {
    private static let enabledKey = "subscription.enabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func detected(records: [PaymentRecordModel]) -> [DetectedSubscription] {
        SubscriptionDetector().detect(records: records.map { $0.toCoreRecord() })
    }

    /// 为已检测到的订阅安排"扣款前一天 9:00"的提醒。
    static func refreshNotifications(records: [PaymentRecordModel]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix("subscription-") }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard isEnabled else { return }

        let calendar = Calendar.current
        let now = Date()
        for subscription in detected(records: records) {
            guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: subscription.nextDueDate) else {
                continue
            }
            let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore) ?? dayBefore
            guard fire > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "订阅扣款提醒"
            if ReminderService.showAmounts {
                content.body = "「\(subscription.merchant)」明天将扣款 ¥\(LedgerFormatters.string(from: subscription.amount))"
            } else {
                content.body = "「\(subscription.merchant)」明天有一笔订阅扣款"
            }
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "subscription-\(subscription.id)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
