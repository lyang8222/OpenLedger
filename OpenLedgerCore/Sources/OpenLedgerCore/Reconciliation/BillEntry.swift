import Foundation

/// 平台导出的账单流水中的一笔记录。
public struct BillEntry: Codable, Equatable, Hashable, Sendable {
    public enum Platform: String, Codable, Sendable {
        case wechat
        case alipay
        case unionpay
        case douyin
    }

    public enum Direction: String, Codable, Sendable {
        case income
        case expense
        case neutral
    }

    public var platform: Platform
    public var paidAt: Date
    public var category: String?
    public var counterparty: String?
    public var itemDescription: String?
    public var direction: Direction
    /// 带符号金额：支出为负，收入/中性为正。
    public var amount: Decimal
    public var method: String?
    public var status: String?
    public var transactionId: String?
    public var merchantOrderId: String?
    public var note: String?

    public init(
        platform: Platform,
        paidAt: Date,
        category: String? = nil,
        counterparty: String? = nil,
        itemDescription: String? = nil,
        direction: Direction,
        amount: Decimal,
        method: String? = nil,
        status: String? = nil,
        transactionId: String? = nil,
        merchantOrderId: String? = nil,
        note: String? = nil
    ) {
        self.platform = platform
        self.paidAt = paidAt
        self.category = category
        self.counterparty = counterparty
        self.itemDescription = itemDescription
        self.direction = direction
        self.amount = amount
        self.method = method
        self.status = status
        self.transactionId = transactionId
        self.merchantOrderId = merchantOrderId
        self.note = note
    }
}
