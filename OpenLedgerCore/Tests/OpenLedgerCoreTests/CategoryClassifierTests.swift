import Foundation
import XCTest
@testable import OpenLedgerCore

final class CategoryClassifierTests: XCTestCase {
    private let classifier = CategoryClassifier()

    func testExpenseCategories() {
        XCTAssertEqual(
            classifier.classify(merchant: "星巴克咖啡", itemDescription: nil, amount: Decimal(string: "-30.00")!),
            .dining
        )
        XCTAssertEqual(
            classifier.classify(merchant: "中国石化加油站", itemDescription: nil, amount: Decimal(string: "-200.00")!),
            .transport
        )
        XCTAssertEqual(
            classifier.classify(merchant: "拼多多平台商户", itemDescription: nil, amount: Decimal(string: "-10.00")!),
            .shopping
        )
        XCTAssertEqual(
            classifier.classify(merchant: "长春肿瘤医院", itemDescription: nil, amount: Decimal(string: "-5.00")!),
            .health
        )
    }

    func testIncomeAndUnknown() {
        XCTAssertEqual(
            classifier.classify(merchant: nil, itemDescription: nil, amount: Decimal(string: "5000.00")!),
            .income
        )
        XCTAssertEqual(
            classifier.classify(merchant: "奇怪商户名", itemDescription: nil, amount: Decimal(string: "-1.00")!),
            .other
        )
    }
}
