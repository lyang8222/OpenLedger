import Foundation
import OpenLedgerCore

/// App 与小组件共享的支出摘要快照（存于 App Group UserDefaults）。
struct WidgetSummarySnapshot {
    let todayCount: Int
    let todayAmount: Decimal
    let monthCount: Int
    let monthAmount: Decimal
    let updatedAt: Date?

    static let appGroup = "group.com.openledger.app"

    private enum Key {
        static let todayCount = "widget.todayCount"
        static let todayAmount = "widget.todayAmount"
        static let monthCount = "widget.monthCount"
        static let monthAmount = "widget.monthAmount"
        static let updatedAt = "widget.updatedAt"
    }

    static func update(records: [PaymentRecord]) {
        let builder = BillSummaryBuilder()
        let now = Date()
        let today = builder.stats(records: records, period: .daily, now: now)
        let month = builder.stats(records: records, period: .monthly, now: now)

        let defaults = UserDefaults(suiteName: appGroup)
        defaults?.set(today.count, forKey: Key.todayCount)
        defaults?.set(NSDecimalNumber(decimal: today.amount).stringValue, forKey: Key.todayAmount)
        defaults?.set(month.count, forKey: Key.monthCount)
        defaults?.set(NSDecimalNumber(decimal: month.amount).stringValue, forKey: Key.monthAmount)
        defaults?.set(now, forKey: Key.updatedAt)
    }

    static func load() -> WidgetSummarySnapshot {
        let defaults = UserDefaults(suiteName: appGroup)

        func decimal(_ key: String) -> Decimal {
            guard let raw = defaults?.string(forKey: key),
                  let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else {
                return .zero
            }
            return value
        }

        return WidgetSummarySnapshot(
            todayCount: defaults?.integer(forKey: Key.todayCount) ?? 0,
            todayAmount: decimal(Key.todayAmount),
            monthCount: defaults?.integer(forKey: Key.monthCount) ?? 0,
            monthAmount: decimal(Key.monthAmount),
            updatedAt: defaults?.object(forKey: Key.updatedAt) as? Date
        )
    }
}
