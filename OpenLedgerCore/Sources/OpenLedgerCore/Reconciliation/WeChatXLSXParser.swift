import Foundation
import zlib

/// 解析微信支付导出的 xlsx 账单（内置最小 ZIP + XML 解析，无需第三方库）。
public struct WeChatBillParser: Sendable {
    public init() {}

    public func parse(data: Data) throws -> [BillEntry] {
        let archive = try ZipArchive(data: data)

        guard let sharedData = archive.entry(named: "xl/sharedStrings.xml"),
              let sheetData = archive.entry(named: "xl/worksheets/sheet1.xml") else {
            throw BillParseError.headerNotFound
        }

        let sharedStrings = try SharedStringsParser().parse(data: sharedData)
        let rows = try SheetParser(sharedStrings: sharedStrings).parse(data: sheetData)

        guard let headerRow = rows.first(where: { row in
            row.values.contains { $0 == "交易时间" } && row.values.contains { $0 == "交易单号" }
        }) else {
            throw BillParseError.headerNotFound
        }

        func headerColumn(_ name: String) -> Int? {
            headerRow.first(where: { $0.value == name })?.key
        }

        guard let timeColumn = headerColumn("交易时间"),
              let directionColumn = headerColumn("收/支"),
              let amountColumn = headerColumn("金额(元)") else {
            throw BillParseError.headerNotFound
        }

        let typeColumn = headerColumn("交易类型")
        let counterpartyColumn = headerColumn("交易对方")
        let descriptionColumn = headerColumn("商品")
        let methodColumn = headerColumn("支付方式")
        let statusColumn = headerColumn("当前状态")
        let orderColumn = headerColumn("交易单号")
        let merchantOrderColumn = headerColumn("商户单号")
        let noteColumn = headerColumn("备注")

        var entries: [BillEntry] = []

        for row in rows where row != headerRow {
            guard let timeText = row[timeColumn],
                  let serial = Double(timeText),
                  let amountText = row[amountColumn],
                  let magnitude = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) else {
                continue
            }

            let directionText = row[directionColumn] ?? ""
            let direction: BillEntry.Direction
            switch directionText {
            case "收入": direction = .income
            case "支出": direction = .expense
            default: direction = .neutral
            }

            let amount = direction == .expense ? -abs(magnitude) : abs(magnitude)

            entries.append(BillEntry(
                platform: .wechat,
                paidAt: Self.dateFromExcelSerial(serial),
                category: typeColumn.flatMap { row[$0] },
                counterparty: counterpartyColumn.flatMap { row[$0] },
                itemDescription: descriptionColumn.flatMap { row[$0] },
                direction: direction,
                amount: amount,
                method: methodColumn.flatMap { row[$0] },
                status: statusColumn.flatMap { row[$0] },
                transactionId: orderColumn.flatMap { row[$0] }.flatMap(Self.nonEmpty),
                merchantOrderId: merchantOrderColumn.flatMap { row[$0] }.flatMap(Self.nonEmpty),
                note: noteColumn.flatMap { row[$0] }.flatMap(Self.nonEmpty)
            ))
        }

        return entries
    }

    /// Excel 序列号 → Date。微信导出时间为 UTC+8，这里按 UTC+8 墙钟时间存储。
    static func dateFromExcelSerial(_ serial: Double) -> Date {
        let secondsSinceEpoch = (serial - 25569) * 86_400 - 28_800
        return Date(timeIntervalSince1970: secondsSinceEpoch)
    }

    private static func nonEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty || t == "/" ? nil : t
    }
}

// MARK: - 最小 ZIP 读取

private struct ZipEntry {
    let name: String
    let method: UInt16
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let localHeaderOffset: UInt32
}

private struct ZipArchive {
    let data: Data
    private let entries: [ZipEntry]

    init(data: Data) throws {
        self.data = data
        entries = try Self.readCentralDirectory(data)
    }

    func entry(named name: String) -> Data? {
        guard let entry = entries.first(where: { $0.name == name }) else { return nil }
        return extract(entry)
    }

    private static func readCentralDirectory(_ data: Data) throws -> [ZipEntry] {
        // 从文件末尾定位 EOCD，避免在压缩数据中误扫到中央目录签名
        var eocdOffset: Int?
        let minimumSize = 22
        guard data.count >= minimumSize else { return [] }
        var cursor = data.count - minimumSize
        while cursor >= 0 {
            if readUInt32(data, at: cursor) == 0x06054B50 {
                eocdOffset = cursor
                break
            }
            cursor -= 1
        }
        guard let eocdOffset else { return [] }

        let entryCount = Int(readUInt16(data, at: eocdOffset + 10))
        let centralOffset = Int(readUInt32(data, at: eocdOffset + 16))
        var entries: [ZipEntry] = []
        var offset = centralOffset
        for _ in 0..<entryCount {
            guard offset + 46 <= data.count else { break }
            let signature = readUInt32(data, at: offset)
            guard signature == 0x02014B50 else { break }
            let method = readUInt16(data, at: offset + 10)
            let compressedSize = readUInt32(data, at: offset + 20)
            let uncompressedSize = readUInt32(data, at: offset + 24)
            let nameLength = Int(readUInt16(data, at: offset + 28))
            let extraLength = Int(readUInt16(data, at: offset + 30))
            let commentLength = Int(readUInt16(data, at: offset + 32))
            let localHeaderOffset = readUInt32(data, at: offset + 42)
            let nameData = data.subdata(in: offset + 46..<offset + 46 + nameLength)
            guard let name = String(data: nameData, encoding: .utf8) else {
                offset += 46 + nameLength + extraLength + commentLength
                continue
            }
            entries.append(ZipEntry(
                name: name,
                method: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))
            offset += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    private func extract(_ entry: ZipEntry) -> Data? {
        let localOffset = Int(entry.localHeaderOffset)
        guard localOffset + 30 <= data.count else { return nil }
        let nameLength = Int(Self.readUInt16(data, at: localOffset + 26))
        let extraLength = Int(Self.readUInt16(data, at: localOffset + 28))
        let payloadStart = localOffset + 30 + nameLength + extraLength
        let payloadEnd = payloadStart + Int(entry.compressedSize)
        guard payloadEnd <= data.count else { return nil }

        let payload = data.subdata(in: payloadStart..<payloadEnd)
        if entry.method == 0 {
            return payload
        }
        guard entry.method == 8 else { return nil }
        return Self.inflate(payload, expectedSize: Int(entry.uncompressedSize))
    }

    private static func inflate(_ payload: Data, expectedSize: Int) -> Data? {
        let capacity = expectedSize > 0 ? expectedSize : max(payload.count * 4, 1024)
        var output = Data(count: capacity)
        var result: Data?

        payload.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                guard let srcBase = src.bindMemory(to: Bytef.self).baseAddress,
                      let dstBase = dst.bindMemory(to: Bytef.self).baseAddress else {
                    return
                }

                var stream = z_stream()
                stream.next_in = UnsafeMutablePointer(mutating: srcBase)
                stream.avail_in = uInt(payload.count)
                stream.next_out = dstBase
                stream.avail_out = uInt(capacity)

                guard inflateInit2_(
                    &stream,
                    -MAX_WBITS,
                    ZLIB_VERSION,
                    Int32(MemoryLayout<z_stream>.size)
                ) == Z_OK else {
                    return
                }
                defer { inflateEnd(&stream) }

                var total = 0
                while true {
                    let status = zlib.inflate(&stream, Z_NO_FLUSH)
                    if status == Z_STREAM_END {
                        total = capacity - Int(stream.avail_out)
                        result = Data(bytes: dstBase, count: total)
                        return
                    }
                    if status != Z_OK { return }
                    if stream.avail_out == 0 { return }
                }
            }
        }
        return result
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        data.subdata(in: offset..<offset + 2).withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        data.subdata(in: offset..<offset + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    }
}

// MARK: - XML 解析

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var currentText = ""
    private var collecting = false

    func parse(data: Data) throws -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { throw BillParseError.headerNotFound }
        return strings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "t" {
            collecting = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collecting { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            strings.append(currentText)
            collecting = false
        }
    }
}

private final class SheetParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]

    private var rows: [[Int: String]] = []
    private var currentRow: [Int: String] = [:]
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentValue = ""

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parse(data: Data) throws -> [[Int: String]] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { throw BillParseError.headerNotFound }
        return rows
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "row":
            currentRow = [:]
        case "c":
            currentCellRef = attributeDict["r"] ?? ""
            currentCellType = attributeDict["t"] ?? ""
            currentValue = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "v" {
            // 值在结束 c 元素时统一处理
        } else if elementName == "c", !currentCellRef.isEmpty {
            let column = Self.columnIndex(currentCellRef)
            if currentCellType == "s", let index = Int(currentValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                currentRow[column] = index < sharedStrings.count ? sharedStrings[index] : nil
            } else {
                let value = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    currentRow[column] = value
                }
            }
            currentCellRef = ""
        } else if elementName == "row" {
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }
            currentRow = [:]
        }
    }

    private static func columnIndex(_ ref: String) -> Int {
        let letters = ref.prefix { $0.isLetter }.uppercased()
        var result = 0
        for char in letters {
            result = result * 26 + Int(char.asciiValue! - 65) + 1
        }
        return result
    }
}
