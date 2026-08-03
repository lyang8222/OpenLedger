import CryptoKit
import Foundation

public struct ReconciliationReport: Sendable {
    public var matched: [BillEntry]
    public var missingInApp: [BillEntry]
    public var missingInBill: [PaymentRecord]
    public var amountMismatched: [(bill: BillEntry, record: PaymentRecord)]
    public var duplicatesInBill: [BillEntry]

    public init(
        matched: [BillEntry] = [],
        missingInApp: [BillEntry] = [],
        missingInBill: [PaymentRecord] = [],
        amountMismatched: [(BillEntry, PaymentRecord)] = [],
        duplicatesInBill: [BillEntry] = []
    ) {
        self.matched = matched
        self.missingInApp = missingInApp
        self.missingInBill = missingInBill
        self.amountMismatched = amountMismatched
        self.duplicatesInBill = duplicatesInBill
    }
}

/// 对账引擎：以平台账单为准，对照 App 内本地记录。
public struct ReconciliationEngine: Sendable {
    /// 是否把"不计收支/中性交易"（充值、提现、还款等）纳入对账。
    public var includeNeutral: Bool

    public init(includeNeutral: Bool = false) {
        self.includeNeutral = includeNeutral
    }

    public func reconcile(billEntries: [BillEntry], records: [PaymentRecord]) -> ReconciliationReport {
        let candidates = includeNeutral
            ? billEntries
            : billEntries.filter { $0.direction != .neutral }

        var byIdHash: [String: [PaymentRecord]] = [:]
        for record in records {
            if let hash = record.transactionIdHash {
                byIdHash[hash, default: []].append(record)
            }
        }

        var matched: [BillEntry] = []
        var missingInApp: [BillEntry] = []
        var amountMismatched: [(BillEntry, PaymentRecord)] = []
        var duplicatesInBill: [BillEntry] = []
        var matchedRecordIDs = Set<UUID>()
        var seenIDs = Set<String>()

        for entry in candidates {
            let idHash = entry.transactionId.map {
                SHA256.hash(data: Data($0.utf8))
                    .map { String(format: "%02x", $0) }
                    .joined()
            }
            if let idHash {
                if seenIDs.contains(idHash) {
                    duplicatesInBill.append(entry)
                    continue
                }
                seenIDs.insert(idHash)
            }

            let match = findMatch(
                for: entry,
                idHash: idHash,
                byIdHash: byIdHash,
                records: records,
                matchedRecordIDs: matchedRecordIDs
            )

            if let record = match {
                if Self.amountEqual(entry.amount, record.amount) {
                    matched.append(entry)
                } else {
                    amountMismatched.append((entry, record))
                }
                matchedRecordIDs.insert(record.id)
            } else {
                missingInApp.append(entry)
            }
        }

        let missingInBill = records.filter { !matchedRecordIDs.contains($0.id) }
        return ReconciliationReport(
            matched: matched,
            missingInApp: missingInApp,
            missingInBill: missingInBill,
            amountMismatched: amountMismatched,
            duplicatesInBill: duplicatesInBill
        )
    }

    private func findMatch(
        for entry: BillEntry,
        idHash: String?,
        byIdHash: [String: [PaymentRecord]],
        records: [PaymentRecord],
        matchedRecordIDs: Set<UUID>
    ) -> PaymentRecord? {
        if let idHash, let candidates = byIdHash[idHash] {
            return candidates.first { !matchedRecordIDs.contains($0.id) }
        }

        // 兜底：无单号时按 平台 + 金额 + 时间窗口（±5 分钟）匹配
        return records.first { record in
            guard !matchedRecordIDs.contains(record.id),
                  record.platform.rawValue == entry.platform.rawValue,
                  Self.amountEqual(entry.amount, record.amount),
                  let paidAt = record.paidAt else {
                return false
            }
            return abs(paidAt.timeIntervalSince(entry.paidAt)) <= 300
        }
    }

    static func amountEqual(_ a: Decimal, _ b: Decimal) -> Bool {
        abs(a - b) <= Decimal(0.005)
    }
}
