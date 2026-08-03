import CryptoKit
import Foundation
import Security

public enum ArchiveError: Error {
    case invalidFormat
    case unsupportedVersion
    case randomGenerationFailed
    case wrongPassphrase
}

/// 加密备份包：口令派生密钥 + AES-GCM，结构为
/// 魔数(4B) | 版本(1B) | 盐(16B) | 密文(nonce+ct+tag)。
public struct EncryptedArchive: Sendable {
    public static let magic = "OLLG"
    public static let currentVersion: UInt8 = 1

    public struct Payload: Codable, Sendable {
        public var version: Int
        public var exportedAt: Date
        public var records: [PaymentRecord]

        public init(version: Int, exportedAt: Date, records: [PaymentRecord]) {
            self.version = version
            self.exportedAt = exportedAt
            self.records = records
        }
    }

    public init() {}

    public func export(records: [PaymentRecord], passphrase: String) throws -> Data {
        let salt = try Self.randomBytes(16)
        let key = CryptoService.deriveKey(passphrase: passphrase, salt: salt)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(
            Payload(version: Int(Self.currentVersion), exportedAt: Date(), records: records)
        )

        let sealed = try AES.GCM.seal(payload, using: key)
        guard let combined = sealed.combined else {
            throw CryptoServiceError.encryptionFailed
        }

        var output = Data(Self.magic.utf8)
        output.append(Self.currentVersion)
        output.append(salt)
        output.append(combined)
        return output
    }

    public func importArchive(data: Data, passphrase: String) throws -> [PaymentRecord] {
        let magicLength = Self.magic.utf8.count
        let saltLength = 16
        guard data.count >= magicLength + 1 + saltLength,
              String(data: data.prefix(magicLength), encoding: .utf8) == Self.magic else {
            throw ArchiveError.invalidFormat
        }

        var offset = magicLength
        let version = data[data.index(data.startIndex, offsetBy: offset)]
        offset += 1
        guard version == Self.currentVersion else {
            throw ArchiveError.unsupportedVersion
        }

        let salt = data[data.index(data.startIndex, offsetBy: offset)..<data.index(data.startIndex, offsetBy: offset + saltLength)]
        offset += saltLength
        let sealedData = Data(data[data.index(data.startIndex, offsetBy: offset)...])

        let key = CryptoService.deriveKey(passphrase: passphrase, salt: salt)
        do {
            let sealed = try AES.GCM.SealedBox(combined: sealedData)
            let plain = try AES.GCM.open(sealed, using: key)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Payload.self, from: plain).records
        } catch {
            // 口令错误、数据被篡改或解密后内容损坏，统一按"口令错误"提示
            throw ArchiveError.wrongPassphrase
        }
    }

    private static func randomBytes(_ count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw ArchiveError.randomGenerationFailed
        }
        return data
    }
}
