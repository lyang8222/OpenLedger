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

enum ZipError: Error {
    case wrongPassword
    case unsupportedEncryption
    case corrupt
}

struct ZipEntry {
    let name: String
    let method: UInt16
    let flags: UInt16
    let crc: UInt32
    let modTime: UInt16
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let localHeaderOffset: UInt32
}

struct ZipArchive {
    let data: Data
    let entries: [ZipEntry]

    init(data: Data) throws {
        self.data = data
        entries = try Self.readCentralDirectory(data)
    }

    func entry(named name: String) -> Data? {
        guard let entry = entries.first(where: { $0.name == name }) else { return nil }
        return extract(entry)
    }

    /// 读取条目；加密条目使用 ZIP 传统加密（ZipCrypto）解密。
    func entry(named name: String, password: String) throws -> Data {
        guard let entry = entries.first(where: { $0.name == name }) else {
            throw ZipError.corrupt
        }

        let encrypted = (entry.flags & 0x0001) != 0
        guard !encrypted else {
            guard entry.method != 99 else { throw ZipError.unsupportedEncryption }

            let localOffset = Int(entry.localHeaderOffset)
            guard localOffset + 30 <= data.count else { throw ZipError.corrupt }
            let nameLength = Int(Self.readUInt16(data, at: localOffset + 26))
            let extraLength = Int(Self.readUInt16(data, at: localOffset + 28))
            let payloadStart = localOffset + 30 + nameLength + extraLength
            let total = Int(entry.compressedSize)
            guard payloadStart + total <= data.count, total > 12 else {
                throw ZipError.corrupt
            }

            let header = data.subdata(in: payloadStart..<payloadStart + 12)
            let body = data.subdata(in: payloadStart + 12..<payloadStart + total)

            var crypto = ZipCrypto(password: password)
            let decryptedHeader = crypto.decrypt(header)
            let expectedCheck: UInt8 = (entry.flags & 0x0008) != 0
                ? UInt8(truncatingIfNeeded: entry.modTime >> 8)
                : UInt8(truncatingIfNeeded: entry.crc >> 24)
            guard decryptedHeader.last == expectedCheck else {
                throw ZipError.wrongPassword
            }

            let decrypted = crypto.decrypt(body)
            let inflated: Data
            if entry.method == 8 {
                guard let value = Self.inflate(decrypted, expectedSize: Int(entry.uncompressedSize)) else {
                    throw ZipError.corrupt
                }
                inflated = value
            } else {
                inflated = decrypted
            }
            guard Self.crc32(inflated) == entry.crc else {
                throw ZipError.wrongPassword
            }
            return inflated
        }

        guard let value = extract(entry) else { throw ZipError.corrupt }
        return value
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
            let flags = readUInt16(data, at: offset + 8)
            let method = readUInt16(data, at: offset + 10)
            let modTime = readUInt16(data, at: offset + 12)
            let crc = readUInt32(data, at: offset + 16)
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
                flags: flags,
                crc: crc,
                modTime: modTime,
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

    // MARK: - CRC32（ZipCrypto 与校验用）

    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for n in 0..<256 {
            var c = UInt32(n)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1
            }
            table[n] = c
        }
        return table
    }()

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    static func crc32Update(_ crc: UInt32, _ byte: UInt8) -> UInt32 {
        crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
    }
}

// MARK: - ZIP 传统加密（ZipCrypto）

struct ZipCrypto {
    private var key0: UInt32 = 0x12345678
    private var key1: UInt32 = 0x23456789
    private var key2: UInt32 = 0x34567890

    init(password: String) {
        for byte in Data(password.utf8) {
            update(byte)
        }
    }

    mutating func decrypt(_ data: Data) -> Data {
        var output = Data()
        output.reserveCapacity(data.count)
        for byte in data {
            let temp = (key2 & 0xFFFF) | 2
            let plain = UInt8(truncatingIfNeeded: ((temp &* (temp ^ 1)) >> 8) & 0xFF) ^ byte
            output.append(plain)
            update(plain)
        }
        return output
    }

    private mutating func update(_ byte: UInt8) {
        key0 = ZipArchive.crc32Update(key0, byte)
        key1 = key1 &+ (key0 & 0xFF)
        key1 = key1 &* 134775813 &+ 1
        key2 = ZipArchive.crc32Update(key2, UInt8(truncatingIfNeeded: key1 >> 24))
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
