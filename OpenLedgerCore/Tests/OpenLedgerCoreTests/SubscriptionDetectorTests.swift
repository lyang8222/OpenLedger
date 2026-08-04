import Foundation
import XCTest
@testable import OpenLedgerCore

final class SubscriptionDetectorTests: XCTestCase {
    func testMonthlySubscription() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
        }

        let records = [
            PaymentRecord(amount: Decimal(string: "-19.00")!, merchant: "视频会员", paidAt: date(2026, 8, 1)),
            PaymentRecord(amount: Decimal(string: "-19.00")!, merchant: "视频会员", paidAt: date(2026, 9, 1)),
            PaymentRecord(amount: Decimal(string: "-19.00")!, merchant: "视频会员", paidAt: date(2026, 10, 1))
        ]

        let subs = SubscriptionDetector().detect(records: records, calendar: calendar)
        XCTAssertEqual(subs.count, 1)
        XCTAssertEqual(subs[0].cadence, .monthly)
        XCTAssertEqual(subs[0].nextDueDate, date(2026, 11, 1))
    }

    func testIrregularAmountsAreIgnored() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        func date(_ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 10))!
        }

        let records = [
            PaymentRecord(amount: Decimal(string: "-5.00")!, merchant: "早餐店", paidAt: date(1)),
            PaymentRecord(amount: Decimal(string: "-12.00")!, merchant: "早餐店", paidAt: date(8))
        ]
        XCTAssertTrue(SubscriptionDetector().detect(records: records, calendar: calendar).isEmpty)
    }
}
