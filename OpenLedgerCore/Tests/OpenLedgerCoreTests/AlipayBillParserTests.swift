import Foundation
import XCTest
@testable import OpenLedgerCore

final class AlipayBillParserTests: XCTestCase {
    func testParseSyntheticCSV() throws {
        let csv = """
        --------------------------------
        导出信息：
        姓名：测试

        交易时间,交易分类,交易对方,对方账号,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号,商家订单号,备注,
        2026-08-01 19:13:57,商业服务,杭州深度求索,/,DeepSeek-API服务,支出,9.88,农业银行信用卡(5561),交易成功,2026080123001417881433911615,10P2088431103081731,,
        2026-07-10 16:56:41,信用借还,花呗,/,花呗主动还款,不计收支,780.96,建设银行储蓄卡(7023),还款成功,2026071029020999880132064051,,,
        """

        let entries = try AlipayBillParser().parse(data: Data(csv.utf8))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].platform, .alipay)
        XCTAssertEqual(entries[0].direction, .expense)
        XCTAssertEqual(entries[0].amount, Decimal(string: "-9.88"))
        XCTAssertEqual(entries[0].transactionId, "2026080123001417881433911615")
        XCTAssertEqual(entries[1].direction, .neutral)
        XCTAssertEqual(entries[1].amount, Decimal(string: "780.96"))
    }
}
