import Foundation

public enum SummaryPeriod: String, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case quarterly
    case yearly

    public var label: String {
        switch self {
        case .daily: "今日"
        case .weekly: "本周"
        case .monthly: "本月"
        case .quarterly: "本季度"
        case .yearly: "今年"
        }
    }
}

/// 账单总结文案生成：按周期统计支出金额与笔数。
public struct BillSummaryBuilder: Sendable {
    public init() {}

    public func range(
        for period: SummaryPeriod,
        now: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        var cal = calendar
        cal.firstWeekday = 2 // 周一为一周开始

        let start: Date
        let end: Date
        switch period {
        case .daily:
            start = cal.startOfDay(for: now)
            end = cal.date(byAdding: .day, value: 1, to: start) ?? now
        case .weekly:
            start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
                ?? cal.startOfDay(for: now)
            end = cal.date(byAdding: .day, value: 7, to: start) ?? now
        case .monthly:
            start = cal.date(from: cal.dateComponents([.year, .month], from: now))
                ?? cal.startOfDay(for: now)
            end = cal.date(byAdding: .month, value: 1, to: start) ?? now
        case .quarterly:
            let month = cal.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var comps = cal.dateComponents([.year], from: now)
            comps.month = quarterStartMonth
            comps.day = 1
            start = cal.date(from: comps) ?? cal.startOfDay(for: now)
            end = cal.date(byAdding: .month, value: 3, to: start) ?? now
        case .yearly:
            start = cal.date(from: cal.dateComponents([.year], from: now))
                ?? cal.startOfDay(for: now)
            end = cal.date(byAdding: .year, value: 1, to: start) ?? now
        }
        return (start, end)
    }

    public func summary(
        records: [PaymentRecord],
        period: SummaryPeriod,
        now: Date = Date(),
        calendar: Calendar = .current,
        showAmounts: Bool = true
    ) -> String {
        let range = self.range(for: period, now: now, calendar: calendar)
        let expenses = records.filter { record in
            guard let paidAt = record.paidAt, record.amount < 0 else { return false }
            return paidAt >= range.start && paidAt < range.end
        }

        guard !expenses.isEmpty else {
            return "\(period.label)暂无支出记录"
        }

        let total = expenses.reduce(Decimal.zero) { $0 + abs($1.amount) }
        if showAmounts {
            return "\(period.label)支出 ¥\(Self.amountText(total))，共 \(expenses.count) 笔"
        }
        return "\(period.label)新增 \(expenses.count) 笔支出，点开查看详情"
    }

    private static func amountText(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
