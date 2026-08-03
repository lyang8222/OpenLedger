import Foundation
import XCTest
@testable import OpenLedgerCore

final class EncryptedArchiveTests: XCTestCase {
    private func sampleRecords() -> [PaymentRecord] {
        [
            PaymentRecord(
                amount: Decimal(string: "-35.00")!,
                merchant: "大红川天椒",
                paidAt: Date(timeIntervalSince1970: 1_700_000_000),
                platform: .wechat,
                transactionId: "4500000272202608037277512581",
                transactionIdHash: "abc123",
                status: "支付成功"
            ),
            PaymentRecord(
                amount: Decimal(string: "780.96")!,
                merchant: "花呗",
                paidAt: Date(timeIntervalSince1970: 1_700_000_100),
                platform: .alipay,
                transactionId: "2026071029020999880132064051",
                status: "还款成功"
            )
        ]
    }

    func testExportImportRoundTrip() throws {
        let archive = EncryptedArchive()
        let data = try archive.export(records: sampleRecords(), passphrase: "正确口令123")

        let restored = try archive.importArchive(data: data, passphrase: "正确口令123")
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].merchant, "大红川天椒")
        XCTAssertEqual(restored[0].transactionId, "4500000272202608037277512581")
        XCTAssertEqual(restored[1].amount, Decimal(string: "780.96"))
        XCTAssertEqual(restored[1].platform, .alipay)
    }

    func testWrongPassphraseFails() throws {
        let archive = EncryptedArchive()
        let data = try archive.export(records: sampleRecords(), passphrase: "正确口令123")

        XCTAssertThrowsError(try archive.importArchive(data: data, passphrase: "错误口令"))
    }

    func testTamperedDataFails() throws {
        let archive = EncryptedArchive()
        var data = try archive.export(records: sampleRecords(), passphrase: "正确口令123")
        data[data.count - 1] ^= 0xFF

        XCTAssertThrowsError(try archive.importArchive(data: data, passphrase: "正确口令123"))
    }
}
