import Foundation

public struct MonthlySummary: Identifiable, Sendable {
    public let month: Date
    public let income: Decimal
    public let expense: Decimal

    public var id: Date { month }

    public init(month: Date, income: Decimal, expense: Decimal) {
        self.month = month
        self.income = income
        self.expense = expense
    }
}

/// 按自然月汇总收入与支出，供账单页图表使用。
public struct ChartDataBuilder: Sendable {
    public init() {}

    public func monthlySummaries(
        records: [PaymentRecord],
        months: Int = 6,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MonthlySummary] {
        guard months > 0 else { return [] }

        let current = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)

        var summaries: [MonthlySummary] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: current),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                continue
            }

            var income = Decimal.zero
            var expense = Decimal.zero
            for record in records {
                guard let paidAt = record.paidAt,
                      paidAt >= monthStart,
                      paidAt < nextMonth else {
                    continue
                }
                if record.amount > 0 {
                    income += record.amount
                } else {
                    expense += abs(record.amount)
                }
            }
            summaries.append(MonthlySummary(month: monthStart, income: income, expense: expense))
        }
        return summaries
    }
}
