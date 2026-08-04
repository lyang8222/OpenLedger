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

public struct CategorySummary: Identifiable, Sendable {
    public let category: ExpenseCategory
    public let amount: Decimal
    public let count: Int

    public var id: String { category.rawValue }

    public init(category: ExpenseCategory, amount: Decimal, count: Int) {
        self.category = category
        self.amount = amount
        self.count = count
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

    /// 按分类汇总本月支出（收入不计入），供分类占比图使用。
    public func categorySummaries(
        records: [PaymentRecord],
        now: Date = Date(),
        calendar: Calendar = .current,
        userRules: [CategoryRule] = []
    ) -> [CategorySummary] {
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month

        var map: [ExpenseCategory: (amount: Decimal, count: Int)] = [:]
        let classifier = CategoryClassifier()

        for record in records {
            guard let paidAt = record.paidAt,
                  record.amount < 0,
                  paidAt >= month,
                  paidAt < nextMonth else {
                continue
            }
            let category = classifier.classify(
                merchant: record.merchant,
                itemDescription: nil,
                amount: record.amount,
                userRules: userRules
            )
            let current = map[category] ?? (.zero, 0)
            map[category] = (current.amount + abs(record.amount), current.count + 1)
        }

        return map
            .map { CategorySummary(category: $0.key, amount: $0.value.amount, count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
    }
}
