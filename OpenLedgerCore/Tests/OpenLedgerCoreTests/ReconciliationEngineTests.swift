import CryptoKit
import Foundation
import XCTest
@testable import OpenLedgerCore

final class ReconciliationEngineTests: XCTestCase {
    private func hash(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func testReconcileScenarios() {
        let records = [
            PaymentRecord(
                amount: Decimal(string: "-9.88")!,
                merchant: "杭州深度求索",
                paidAt: Date(timeIntervalSince1970: 1_784_954_000),
                platform: .alipay,
                transactionId: "id-1",
                transactionIdHash: hash("id-1"),
                status: "交易成功"
            ),
            PaymentRecord(
                amount: Decimal(string: "-66.66")!,
                merchant: "金额不一致",
                paidAt: Date(timeIntervalSince1970: 1_784_700_000),
                platform: .alipay,
                transactionId: "id-3",
                transactionIdHash: hash("id-3"),
                status: "交易成功"
            )
        ]

        let bill = [
            BillEntry(
                platform: .alipay,
                paidAt: Date(timeIntervalSince1970: 1_784_954_000),
                counterparty: "杭州深度求索",
                direction: .expense,
                amount: Decimal(string: "-9.88")!,
                transactionId: "id-1"
            ),
            BillEntry(
                platform: .alipay,
                paidAt: Date(timeIntervalSince1970: 1_784_800_000),
                counterparty: "漏记商户",
                direction: .expense,
                amount: Decimal(string: "-12.00")!,
                transactionId: "id-2"
            ),
            BillEntry(
                platform: .alipay,
                paidAt: Date(timeIntervalSince1970: 1_784_700_000),
                counterparty: "金额不一致",
                direction: .expense,
                amount: Decimal(string: "-99.00")!,
                transactionId: "id-3"
            ),
            BillEntry(
                platform: .alipay,
                paidAt: Date(timeIntervalSince1970: 1_784_600_000),
                counterparty: "重复单号",
                direction: .expense,
                amount: Decimal(string: "-1.00")!,
                transactionId: "dup"
            ),
            BillEntry(
                platform: .alipay,
                paidAt: Date(timeIntervalSince1970: 1_784_600_000),
                counterparty: "重复单号2",
                direction: .expense,
                amount: Decimal(string: "-1.00")!,
                transactionId: "dup"
            )
        ]

        let report = ReconciliationEngine().reconcile(billEntries: bill, records: records)

        XCTAssertEqual(report.matched.count, 1)
        XCTAssertEqual(report.amountMismatched.count, 1)
        XCTAssertEqual(report.missingInApp.count, 2)
        XCTAssertEqual(report.duplicatesInBill.count, 1)
        XCTAssertEqual(report.missingInBill.count, 0)
    }
}
