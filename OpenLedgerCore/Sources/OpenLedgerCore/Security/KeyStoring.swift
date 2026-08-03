import Foundation
import Security

/// 密钥存储抽象：App 内用 Keychain，测试用内存实现。
public protocol KeyStoring: Sendable {
    func loadData(identifier: String) throws -> Data?
    func storeData(_ data: Data, identifier: String) throws
    func deleteData(identifier: String) throws
}

public struct InMemoryKeyStorage: KeyStoring {
    private final class Box: @unchecked Sendable {
        let lock = NSLock()
        var storage: [String: Data] = [:]
    }

    private let box = Box()

    public init() {}

    public func loadData(identifier: String) throws -> Data? {
        box.lock.lock()
        defer { box.lock.unlock() }
        return box.storage[identifier]
    }

    public func storeData(_ data: Data, identifier: String) throws {
        box.lock.lock()
        defer { box.lock.unlock() }
        box.storage[identifier] = data
    }

    public func deleteData(identifier: String) throws {
        box.lock.lock()
        defer { box.lock.unlock() }
        box.storage.removeValue(forKey: identifier)
    }
}

/// Keychain 存储：仅本设备可用（ThisDeviceOnly），不随备份迁移。
public struct KeychainKeyStorage: KeyStoring {
    private let service: String

    public init(service: String = "com.openledger.app.keys") {
        self.service = service
    }

    private func baseQuery(identifier: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier
        ]
    }

    public func loadData(identifier: String) throws -> Data? {
        var query = baseQuery(identifier: identifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        return item as? Data
    }

    public func storeData(_ data: Data, identifier: String) throws {
        let query = baseQuery(identifier: identifier)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func deleteData(identifier: String) throws {
        let status = SecItemDelete(baseQuery(identifier: identifier) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

public struct KeychainError: Error, CustomStringConvertible {
    public let status: OSStatus

    public var description: String {
        "Keychain 操作失败：\(status)"
    }
}
