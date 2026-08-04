import Foundation
import OpenLedgerCore
import UserNotifications

enum ReminderKeys {
    static let enabled = "reminder.enabled"
    static let daily = "reminder.daily"
    static let weekly = "reminder.weekly"
    static let monthly = "reminder.monthly"
    static let quarterly = "reminder.quarterly"
    static let yearly = "reminder.yearly"
    static let dailyTime = "reminder.dailyTime"
    static let weeklyWeekday = "reminder.weeklyWeekday"
    static let showAmounts = "reminder.showAmounts"
}

@MainActor
enum ReminderService {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: ReminderKeys.enabled)
    }

    static var showAmounts: Bool {
        UserDefaults.standard.bool(forKey: ReminderKeys.showAmounts)
    }

    static var dailyTimeMinutes: Int {
        let stored = UserDefaults.standard.integer(forKey: ReminderKeys.dailyTime)
        return stored > 0 ? stored : 21 * 60
    }

    static var weeklyWeekday: Int {
        let stored = UserDefaults.standard.integer(forKey: ReminderKeys.weeklyWeekday)
        return stored >= 1 && stored <= 7 ? stored : 2
    }

    static func isPeriodEnabled(_ period: SummaryPeriod) -> Bool {
        let key: String
        switch period {
        case .daily: key = ReminderKeys.daily
        case .weekly: key = ReminderKeys.weekly
        case .monthly: key = ReminderKeys.monthly
        case .quarterly: key = ReminderKeys.quarterly
        case .yearly: key = ReminderKeys.yearly
        }
        // 未显式设置过的周期默认开启（@AppStorage 的默认值不会自动写入 UserDefaults）
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 重新计算汇总并重排所有已启用的通知。
    static func refreshSummaries(records: [PaymentRecordModel]) async {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

        let coreRecords = records.map { $0.toCoreRecord() }
        let builder = BillSummaryBuilder()
        let now = Date()

        for period in SummaryPeriod.allCases where isPeriodEnabled(period) {
            for trigger in triggers(for: period) {
                let content = UNMutableNotificationContent()
                content.title = "\(period.label)账单总结"
                content.body = builder.summary(
                    records: coreRecords,
                    period: period,
                    now: now,
                    showAmounts: showAmounts
                )
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: identifier(for: period, triggerIndex: trigger.index),
                    content: content,
                    trigger: trigger.trigger
                )
                try? await center.add(request)
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: allIdentifiers)
    }

    /// 返回当前已排程的提醒摘要，用于调试。
    static func pendingSummary() async -> String {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        guard !requests.isEmpty else {
            return "当前没有已排程的提醒"
        }
        let lines = requests.compactMap { request -> String? in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
                return nil
            }
            let next = trigger.nextTriggerDate()?
                .formatted(date: .abbreviated, time: .shortened) ?? "未知"
            return "\(request.identifier)：\(next)"
        }
        return lines.joined(separator: "\n")
    }

    private static var allIdentifiers: [String] {
        var identifiers: [String] = []
        for period in SummaryPeriod.allCases {
            if period == .quarterly {
                identifiers += [1, 4, 7, 10].map { "reminder-quarterly-\($0)" }
            } else {
                identifiers.append("reminder-\(period.rawValue)")
            }
        }
        return identifiers
    }

    private static func identifier(for period: SummaryPeriod, triggerIndex: Int) -> String {
        if period == .quarterly {
            return "reminder-quarterly-\(triggerIndex)"
        }
        return "reminder-\(period.rawValue)"
    }

    private static func triggers(
        for period: SummaryPeriod
    ) -> [(index: Int, trigger: UNCalendarNotificationTrigger)] {
        let hour = dailyTimeMinutes / 60
        let minute = dailyTimeMinutes % 60

        switch period {
        case .daily:
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            return [(0, UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))]

        case .weekly:
            var comps = DateComponents()
            comps.weekday = weeklyWeekday
            comps.hour = hour
            comps.minute = minute
            return [(0, UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))]

        case .monthly:
            var comps = DateComponents()
            comps.day = 1
            comps.hour = hour
            comps.minute = minute
            return [(0, UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))]

        case .quarterly:
            return [1, 4, 7, 10].map { month in
                var comps = DateComponents()
                comps.month = month
                comps.day = 1
                comps.hour = hour
                comps.minute = minute
                return (month, UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            }

        case .yearly:
            var comps = DateComponents()
            comps.month = 1
            comps.day = 1
            comps.hour = hour
            comps.minute = minute
            return [(0, UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))]
        }
    }
}

extension PaymentRecordModel {
    func toCoreRecord() -> PaymentRecord {
        PaymentRecord(
            id: id,
            amount: amount,
            currency: currency,
            merchant: merchant,
            category: category,
            paidAt: paidAt,
            platform: platform,
            transactionIdHash: transactionIdHash,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
