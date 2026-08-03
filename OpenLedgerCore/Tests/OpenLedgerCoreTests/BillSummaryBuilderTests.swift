import Foundation
import XCTest
@testable import OpenLedgerCore

final class BillSummaryBuilderTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testDailySummary() {
        let calendar = self.calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 12))!
        let records = [
            PaymentRecord(amount: Decimal(string: "-10.50")!, paidAt: now.addingTimeInterval(-3600)),
            PaymentRecord(amount: Decimal(string: "-5.00")!, paidAt: now.addingTimeInterval(-7200)),
            PaymentRecord(amount: Decimal(string: "-100.00")!, paidAt: calendar.date(byAdding: .day, value: -3, to: now)!),
            PaymentRecord(amount: Decimal(string: "50.00")!, paidAt: now)
        ]

        let builder = BillSummaryBuilder()
        let text = builder.summary(records: records, period: .daily, now: now, calendar: calendar)
        XCTAssertTrue(text.contains("¥15.50"))
        XCTAssertTrue(text.contains("2 笔"))

        let hidden = builder.summary(
            records: records,
            period: .daily,
            now: now,
            calendar: calendar,
            showAmounts: false
        )
        XCTAssertTrue(hidden.contains("新增 2 笔支出"))
        XCTAssertFalse(hidden.contains("¥"))
    }

    func testEmptySummary() {
        let calendar = self.calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 12))!
        let records = [
            PaymentRecord(amount: Decimal(string: "-9.00")!, paidAt: calendar.date(byAdding: .day, value: -10, to: now)!)
        ]

        let text = BillSummaryBuilder().summary(records: records, period: .daily, now: now, calendar: calendar)
        XCTAssertTrue(text.contains("暂无支出"))
    }
}
