import Foundation

public struct ExtractedBill: Sendable {
    public let platform: BillEntry.Platform
    public let fileName: String
    public let entries: [BillEntry]

    public init(platform: BillEntry.Platform, fileName: String, entries: [BillEntry]) {
        self.platform = platform
        self.fileName = fileName
        self.entries = entries
    }
}

public enum BillZipError: Error {
    case notAZip
    case noBillEntryFound
    case wrongPassword
    case unsupportedEncryption
    case parseFailed
}

/// 导入微信/支付宝官方导出的加密 zip 账单。
public struct BillZipImporter: Sendable {
    public init() {}

    public func importBill(data: Data, password: String) throws -> ExtractedBill {
        guard let archive = try? ZipArchive(data: data) else {
            throw BillZipError.notAZip
        }
        guard let target = archive.entries.first(where: {
            let ext = ($0.name as NSString).pathExtension.lowercased()
            return ext == "xlsx" || ext == "csv"
        }) else {
            throw BillZipError.noBillEntryFound
        }

        let raw: Data
        do {
            raw = try archive.entry(named: target.name, password: password)
        } catch ZipError.wrongPassword {
            throw BillZipError.wrongPassword
        } catch ZipError.unsupportedEncryption {
            throw BillZipError.unsupportedEncryption
        } catch {
            throw BillZipError.parseFailed
        }

        do {
            let ext = (target.name as NSString).pathExtension.lowercased()
            if ext == "xlsx" {
                return ExtractedBill(
                    platform: .wechat,
                    fileName: target.name,
                    entries: try WeChatBillParser().parse(data: raw)
                )
            }
            return ExtractedBill(
                platform: .alipay,
                fileName: target.name,
                entries: try AlipayBillParser().parse(data: raw)
            )
        } catch {
            throw BillZipError.parseFailed
        }
    }
}
