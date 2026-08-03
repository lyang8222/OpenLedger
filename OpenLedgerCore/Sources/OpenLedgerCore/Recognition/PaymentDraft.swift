import Foundation

/// OCR + 模板解析后的中间结果，供确认页编辑后落库。
public struct PaymentDraft: Codable, Equatable, Sendable {
    public var platform: PaymentRecord.Platform
    public var amount: Decimal?
    public var merchant: String?
    public var paidAt: Date?
    public var status: String?
    public var transactionId: String?
    public var rawText: String
    public var missingFields: Set<String>

    public init(
        platform: PaymentRecord.Platform = .unknown,
        amount: Decimal? = nil,
        merchant: String? = nil,
        paidAt: Date? = nil,
        status: String? = nil,
        transactionId: String? = nil,
        rawText: String = "",
        missingFields: Set<String> = []
    ) {
        self.platform = platform
        self.amount = amount
        self.merchant = merchant
        self.paidAt = paidAt
        self.status = status
        self.transactionId = transactionId
        self.rawText = rawText
        self.missingFields = missingFields
    }
}
