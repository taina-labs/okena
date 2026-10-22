import Foundation
import Security

/// Thin Keychain wrapper for raw Data. Items are readable only while the
/// phone is unlocked, and never leave this device: the token must not
/// travel in an iCloud backup to a new phone.
public struct Keychain: Sendable {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    /// Replaces any existing item: the delete happens first, so a second
    /// save never fails with `errSecDuplicateItem`. The delete also makes
    /// the accessibility class follow the current constant, so an item
    /// saved by an older build migrates on the next sign in.
    public func set(_ data: Data, account: String) -> TainaResult<Void> {
        remove(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            return .failure(.keychain(status))
        }
        return .success(())
    }

    /// `nil` when the account has no item. That is absence, not failure.
    public func get(account: String) -> TainaResult<Data?> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return .success(item as? Data)
        case errSecItemNotFound:
            return .success(nil)
        default:
            return .failure(.keychain(status))
        }
    }

    /// Deleting an absent item succeeds: removal is idempotent.
    @discardableResult
    public func remove(account: String) -> TainaResult<Void> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(.keychain(status))
        }
        return .success(())
    }
}
