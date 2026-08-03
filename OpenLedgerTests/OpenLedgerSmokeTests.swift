import OpenLedgerCore
import XCTest

final class OpenLedgerSmokeTests: XCTestCase {
    func testPlatformDisplayName() {
        XCTAssertEqual(PaymentRecord.Platform.wechat.displayName, "微信")
        XCTAssertEqual(PaymentRecord.Platform.alipay.displayName, "支付宝")
    }
}
