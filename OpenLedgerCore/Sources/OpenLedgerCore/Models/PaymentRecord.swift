import Foundation

/// 一笔账目的完整记录（跨端/导出/恢复共用模型）。
public struct PaymentRecord: Codable, Identifiable, Equatable, Sendable {
    public enum Platform: String, Codable, CaseIterable, Sendable {
        case wechat
        case alipay
        case unionpay
        case douyin
        case unknown

        public var displayName: String {
            switch self {
            case .wechat: "微信"
            case .alipay: "支付宝"
            case .unionpay: "云闪付"
            case .douyin: "抖音"
            case .unknown: "未知"
            }
        }
    }

    public var id: UUID
    public var amount: Decimal
    public var currency: String
    public var merchant: String?
    public var category: String?
    public var paidAt: Date?
    public var platform: Platform
    public var transactionId: String?
    public var transactionIdHash: String?
    public var itemDescription: String?
    public var rawOcrText: String?
    public var notes: String?
    public var status: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        currency: String = "CNY",
        merchant: String? = nil,
        category: String? = nil,
        paidAt: Date? = nil,
        platform: Platform = .unknown,
        transactionId: String? = nil,
        transactionIdHash: String? = nil,
        itemDescription: String? = nil,
        rawOcrText: String? = nil,
        notes: String? = nil,
        status: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.category = category
        self.paidAt = paidAt
        self.platform = platform
        self.transactionId = transactionId
        self.transactionIdHash = transactionIdHash
        self.itemDescription = itemDescription
        self.rawOcrText = rawOcrText
        self.notes = notes
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
