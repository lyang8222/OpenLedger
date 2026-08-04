import Foundation
import XCTest
@testable import OpenLedgerCore

final class ChartDataBuilderTests: XCTestCase {
    func testMonthlySummaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 10))!

        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
        }

        let records = [
            PaymentRecord(amount: Decimal(string: "-100.00")!, paidAt: date(2026, 8, 3)),
            PaymentRecord(amount: Decimal(string: "-50.50")!, paidAt: date(2026, 8, 10)),
            PaymentRecord(amount: Decimal(string: "200.00")!, paidAt: date(2026, 8, 12)),
            PaymentRecord(amount: Decimal(string: "-30.00")!, paidAt: date(2026, 7, 20)),
            PaymentRecord(amount: Decimal(string: "-999.00")!, paidAt: date(2026, 1, 5))
        ]

        let summaries = ChartDataBuilder().monthlySummaries(
            records: records,
            months: 6,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summaries.count, 6)
        XCTAssertEqual(summaries.last?.income, Decimal(string: "200.00"))
        XCTAssertEqual(summaries.last?.expense, Decimal(string: "150.50"))
        XCTAssertEqual(summaries[4].expense, Decimal(string: "30.00"))
        XCTAssertEqual(summaries[0].expense, Decimal.zero)
    }

    func testCategorySummaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 10))!

        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
        }

        let records = [
            PaymentRecord(amount: Decimal(string: "-30.00")!, merchant: "星巴克咖啡", paidAt: date(2026, 8, 3)),
            PaymentRecord(amount: Decimal(string: "-20.00")!, merchant: "汉堡王", paidAt: date(2026, 8, 5)),
            PaymentRecord(amount: Decimal(string: "-200.00")!, merchant: "中国石化加油站", paidAt: date(2026, 8, 8)),
            PaymentRecord(amount: Decimal(string: "5000.00")!, merchant: "工资", paidAt: date(2026, 8, 1))
        ]

        let summaries = ChartDataBuilder().categorySummaries(records: records, now: now, calendar: calendar)
        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries[0].category, .transport)
        XCTAssertEqual(summaries[1].category, .dining)
        XCTAssertEqual(summaries[1].count, 2)
    }
}
