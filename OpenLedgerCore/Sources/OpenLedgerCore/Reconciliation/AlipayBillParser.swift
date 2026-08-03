import CoreFoundation
import Foundation

public enum BillParseError: Error, Equatable {
    case cannotDecode
    case headerNotFound
    case invalidDate(String)
    case invalidAmount(String)
}

/// 解析支付宝导出的交易明细 CSV（GB18030 或 UTF-8）。
public struct AlipayBillParser: Sendable {
    public init() {}

    public func parse(data: Data) throws -> [BillEntry] {
        guard let text = decode(data) else {
            throw BillParseError.cannotDecode
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard let headerIndex = lines.firstIndex(where: { $0.hasPrefix("交易时间") }) else {
            throw BillParseError.headerNotFound
        }
        let header = CSV.parseLine(lines[headerIndex]).map(trimmed)

        func column(_ name: String) -> Int? {
            header.firstIndex(of: name)
        }

        guard let timeColumn = column("交易时间"),
              let directionColumn = column("收/支"),
              let amountColumn = column("金额") else {
            throw BillParseError.headerNotFound
        }
        let categoryColumn = column("交易分类")
        let counterpartyColumn = column("交易对方")
        let descriptionColumn = column("商品说明")
        let methodColumn = column("收/付款方式")
        let statusColumn = column("交易状态")
        let orderColumn = column("交易订单号")
        let merchantOrderColumn = column("商家订单号")
        let noteColumn = column("备注")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var entries: [BillEntry] = []

        for rawLine in lines[(headerIndex + 1)...] {
            let line = trimmed(rawLine)
            if line.isEmpty || line.hasPrefix("---") || line.hasPrefix("共") { continue }
            let fields = CSV.parseLine(rawLine).map(trimmed)
            guard fields.count > max(timeColumn, directionColumn, amountColumn),
                  !fields[timeColumn].isEmpty else { continue }

            guard let date = formatter.date(from: fields[timeColumn]) else {
                throw BillParseError.invalidDate(fields[timeColumn])
            }
            guard let magnitude = Decimal(string: fields[amountColumn], locale: Locale(identifier: "en_US_POSIX")) else {
                throw BillParseError.invalidAmount(fields[amountColumn])
            }

            let direction: BillEntry.Direction
            switch fields[directionColumn] {
            case "收入": direction = .income
            case "支出": direction = .expense
            default: direction = .neutral
            }

            let amount = direction == .expense ? -abs(magnitude) : abs(magnitude)

            entries.append(BillEntry(
                platform: .alipay,
                paidAt: date,
                category: categoryColumn.map { fields[$0] },
                counterparty: counterpartyColumn.map { fields[$0] },
                itemDescription: descriptionColumn.map { fields[$0] },
                direction: direction,
                amount: amount,
                method: methodColumn.map { fields[$0] },
                status: statusColumn.map { fields[$0] },
                transactionId: orderColumn.map { fields[$0] }.flatMap(nonEmpty),
                merchantOrderId: merchantOrderColumn.map { fields[$0] }.flatMap(nonEmpty),
                note: noteColumn.map { fields[$0] }.flatMap(nonEmpty)
            ))
        }

        return entries
    }

    private func decode(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String(data: data, encoding: String.Encoding(rawValue: nsEncoding))
    }

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nonEmpty(_ s: String) -> String? {
        let t = trimmed(s)
        return t.isEmpty || t == "/" ? nil : t
    }
}
