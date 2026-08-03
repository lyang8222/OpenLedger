import CryptoKit
import Foundation
import XCTest
@testable import OpenLedgerCore

final class CryptoServiceTests: XCTestCase {
    func testMasterKeyIsStable() throws {
        let storage = InMemoryKeyStorage()
        let crypto = CryptoService(keys: storage)

        let first = try crypto.masterKey()
        let second = try crypto.masterKey()

        let firstData = first.withUnsafeBytes { Data($0) }
        let secondData = second.withUnsafeBytes { Data($0) }
        XCTAssertEqual(firstData, secondData)
    }

    func testEncryptDecryptRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let crypto = CryptoService(keys: InMemoryKeyStorage())
        let payload = ["hello": "世界", "n": 42]

        let sealed = try crypto.encrypt(payload, using: key)
        let opened: [String: AnyHashable] = try crypto.decrypt([String: AnyHashable].self, from: sealed, using: key)

        XCTAssertEqual(opened["hello"], "世界")
        XCTAssertEqual(opened["n"], 42)
    }

    func testDecryptWithWrongKeyFails() throws {
        let keyA = SymmetricKey(size: .bits256)
        let keyB = SymmetricKey(size: .bits256)
        let crypto = CryptoService(keys: InMemoryKeyStorage())

        let sealed = try crypto.encrypt("secret", using: keyA)
        XCTAssertThrowsError(try crypto.decrypt(String.self, from: sealed, using: keyB))
    }
}
