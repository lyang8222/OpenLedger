import CryptoKit
import Foundation

public enum CryptoServiceError: Error {
    case encryptionFailed
}

/// 加密服务：主密钥管理（Keychain）+ AES-256-GCM 字段加密。
public struct CryptoService: Sendable {
    private let keys: any KeyStoring

    public init(keys: any KeyStoring = KeychainKeyStorage()) {
        self.keys = keys
    }

    /// 获取（不存在则生成并保存）主密钥。
    public func masterKey(identifier: String = "master") throws -> SymmetricKey {
        if let data = try keys.loadData(identifier: identifier) {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try keys.storeData(data, identifier: identifier)
        return key
    }

    public func encrypt<Value: Encodable>(_ value: Value, using key: SymmetricKey) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(value)
        let sealed = try AES.GCM.seal(payload, using: key)
        guard let combined = sealed.combined else {
            throw CryptoServiceError.encryptionFailed
        }
        return combined
    }

    public func decrypt<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        using key: SymmetricKey
    ) throws -> Value {
        let sealed = try AES.GCM.SealedBox(combined: data)
        let plain = try AES.GCM.open(sealed, using: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: plain)
    }

    /// 由口令派生导出密钥（HKDF-SHA256）。
    public static func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
        let material = SymmetricKey(data: Data(passphrase.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: material,
            salt: salt,
            info: Data("OpenLedger.Archive.v1".utf8),
            outputByteCount: 32
        )
    }
}
