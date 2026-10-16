import Foundation

/// Where the box address lives between launches. The token is a credential
/// and goes to the Keychain; the address is not a secret and goes here.
public protocol HostStore: Sendable {
    func address() async -> InstanceAddress?
    func save(_ address: InstanceAddress) async -> TainaResult<Void>
    func clear() async
}

/// UserDefaults backed. The host is not a secret.
///
/// `@unchecked` because UserDefaults is documented thread-safe and does not
/// carry the conformance itself; the struct only forwards to it.
public struct UserDefaultsHostStore: @unchecked Sendable, HostStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "taina.host") {
        self.defaults = defaults
        self.key = key
    }

    public func address() async -> InstanceAddress? {
        guard let stored = defaults.string(forKey: key), let url = URL(string: stored) else {
            return nil
        }
        // The value was written by save, so it is already a validated
        // address; it does not go through parse again.
        return InstanceAddress(url: url)
    }

    public func save(_ address: InstanceAddress) async -> TainaResult<Void> {
        defaults.set(address.url.absoluteString, forKey: key)
        return .success(())
    }

    public func clear() async {
        defaults.removeObject(forKey: key)
    }
}

/// In memory, for tests and previews. Seeding it starts from an address
/// instead of a setup run.
public actor InMemoryHostStore: HostStore {
    private var stored: InstanceAddress?

    public init(_ address: InstanceAddress? = nil) {
        stored = address
    }

    public func address() -> InstanceAddress? {
        stored
    }

    public func save(_ address: InstanceAddress) async -> TainaResult<Void> {
        stored = address
        return .success(())
    }

    public func clear() {
        stored = nil
    }
}
