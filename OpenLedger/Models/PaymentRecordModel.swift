import CryptoKit
import Foundation
import OpenLedgerCore
import SwiftData

@Model
final class PaymentRecordModel {
    var id: UUID
    var amount: Decimal
    var currency: String
    var merchant: String?
    var category: String?
    var paidAt: Date?
    var platformRaw: String
    var transactionIdEncrypted: Data?
    var transactionIdHash: String?
    var itemDescriptionEncrypted: Data?
    var rawOcrTextEncrypted: Data?
    var notesEncrypted: Data?
    var status: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal = .zero,
        currency: String = "CNY",
        merchant: String? = nil,
        category: String? = nil,
        paidAt: Date? = nil,
        platform: PaymentRecord.Platform = .unknown,
        transactionIdEncrypted: Data? = nil,
        transactionIdHash: String? = nil,
        itemDescriptionEncrypted: Data? = nil,
        rawOcrTextEncrypted: Data? = nil,
        notesEncrypted: Data? = nil,
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
        self.platformRaw = platform.rawValue
        self.transactionIdEncrypted = transactionIdEncrypted
        self.transactionIdHash = transactionIdHash
        self.itemDescriptionEncrypted = itemDescriptionEncrypted
        self.rawOcrTextEncrypted = rawOcrTextEncrypted
        self.notesEncrypted = notesEncrypted
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var platform: PaymentRecord.Platform {
        PaymentRecord.Platform(rawValue: platformRaw) ?? .unknown
    }

    /// 从识别草稿创建记录：交易单号/OCR 原文加密落库，单号另存哈希用于去重。
    static func make(from draft: PaymentDraft, crypto: CryptoService) throws -> PaymentRecordModel {
        let key = try crypto.masterKey()

        let transactionId = draft.transactionId
        let transactionIdHash = transactionId.map(Self.transactionIdHash)
        let transactionIdEncrypted = try transactionId.map {
            try crypto.encrypt($0, using: key)
        }
        let rawOcrTextEncrypted = draft.rawText.isEmpty
            ? nil
            : try crypto.encrypt(draft.rawText, using: key)

        return PaymentRecordModel(
            amount: draft.amount ?? .zero,
            merchant: draft.merchant,
            paidAt: draft.paidAt,
            platform: draft.platform,
            transactionIdEncrypted: transactionIdEncrypted,
            transactionIdHash: transactionIdHash,
            rawOcrTextEncrypted: rawOcrTextEncrypted,
            status: draft.status
        )
    }

    static func transactionIdHash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
