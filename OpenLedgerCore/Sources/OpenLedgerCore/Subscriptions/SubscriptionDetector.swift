import Foundation

public enum SubscriptionCadence: String, CaseIterable, Sendable {
    case weekly
    case monthly
    case yearly

    public var label: String {
        switch self {
        case .weekly: "每周"
        case .monthly: "每月"
        case .yearly: "每年"
        }
    }

    var dayInterval: Double {
        switch self {
        case .weekly: 7
        case .monthly: 30
        case .yearly: 365
        }
    }

    func nextDate(after date: Date, calendar: Calendar) -> Date {
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

public struct DetectedSubscription: Identifiable, Equatable, Sendable {
    public let merchant: String
    public let amount: Decimal
    public let cadence: SubscriptionCadence
    public let occurrences: Int
    public let lastPaidAt: Date
    public let nextDueDate: Date

    public var id: String {
        "\(merchant)|\(cadence.rawValue)|\(NSDecimalNumber(decimal: amount).stringValue)"
    }

    public init(
        merchant: String,
        amount: Decimal,
        cadence: SubscriptionCadence,
        occurrences: Int,
        lastPaidAt: Date,
        nextDueDate: Date
    ) {
        self.merchant = merchant
        self.amount = amount
        self.cadence = cadence
        self.occurrences = occurrences
        self.lastPaidAt = lastPaidAt
        self.nextDueDate = nextDueDate
    }
}

/// 检测周期性扣款：同商户 + 金额一致 + 间隔符合周/月/年周期。
public struct SubscriptionDetector: Sendable {
    public init() {}

    public func detect(
        records: [PaymentRecord],
        now: Date = Date(),
        calendar: Calendar = .current,
        minOccurrences: Int = 2
    ) -> [DetectedSubscription] {
        let expenses = records.filter {
            $0.amount < 0 && $0.paidAt != nil
                && $0.merchant != nil && !$0.merchant!.isEmpty
        }

        var groups: [String: [PaymentRecord]] = [:]
        for record in expenses {
            let key = record.merchant!.trimmingCharacters(in: .whitespacesAndNewlines)
            groups[key, default: []].append(record)
        }

        var results: [DetectedSubscription] = []
        for (merchant, list) in groups where list.count >= minOccurrences {
            let sorted = list.sorted { ($0.paidAt!) < ($1.paidAt!) }
            guard let firstAmount = sorted.first?.amount,
                  sorted.allSatisfy({ abs($0.amount - firstAmount) <= Decimal(0.01) }) else {
                continue
            }

            let dates = sorted.compactMap(\.paidAt)
            let intervals = zip(dates, dates.dropFirst())
                .map { $1.timeIntervalSince($0) / 86_400 }
            guard intervals.count >= minOccurrences - 1 else { continue }

            let matches: [(SubscriptionCadence, Double)] = SubscriptionCadence.allCases.compactMap { cadence in
                let (low, high) = Self.range(for: cadence)
                guard intervals.allSatisfy({ $0 >= low && $0 <= high }) else { return nil }
                let deviation = intervals.map { abs($0 - cadence.dayInterval) }.max() ?? 0
                return (cadence, deviation)
            }

            guard let best = matches.min(by: { $0.1 < $1.1 }) else { continue }
            let last = dates.last!
            let next = best.0.nextDate(after: last, calendar: calendar)
            results.append(DetectedSubscription(
                merchant: merchant,
                amount: abs(firstAmount),
                cadence: best.0,
                occurrences: sorted.count,
                lastPaidAt: last,
                nextDueDate: next
            ))
        }

        return results.sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private static func range(for cadence: SubscriptionCadence) -> (Double, Double) {
        switch cadence {
        case .weekly: (6, 8)
        case .monthly: (25, 35)
        case .yearly: (350, 380)
        }
    }
}
