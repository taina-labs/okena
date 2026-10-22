import Foundation

/// What `POST /session` returns and what gets persisted: the same shape by
/// contract (`token`, `device`, `me`, `tekoa`), so one type, not two. The
/// token is the raw device secret (`tnd_...`), shown once, kept here.
public struct Session: Codable, Sendable, Equatable {
    public let token: String
    public let device: DeviceToken
    public let me: Ava
    public let tekoa: Tekoa

    public init(token: String, device: DeviceToken, me: Ava, tekoa: Tekoa) {
        self.token = token
        self.device = device
        self.me = me
        self.tekoa = tekoa
    }

    /// The identity a restored session already carries, without another
    /// round trip: the shape `GET /me` answers with.
    public var identity: Me {
        Me(ava: me, tekoa: tekoa, device: device)
    }
}

/// `GET /me`: the same identity without the token.
public struct Me: Decodable, Sendable, Equatable {
    public let ava: Ava
    public let tekoa: Tekoa
    public let device: DeviceToken?

    public init(ava: Ava, tekoa: Tekoa, device: DeviceToken?) {
        self.ava = ava
        self.tekoa = tekoa
        self.device = device
    }
}

/// Persists the session between launches. There is no expiry and no refresh:
/// the revocation is the lifecycle. Nothing here schedules anything.
public protocol SessionStorage: Sendable {
    func save(_ session: Session) async -> TainaResult<Void>
    func load() async -> TainaResult<Session?>
    func clear() async -> TainaResult<Void>
}

/// Keychain backed. The whole session round trips as JSON under one account.
public struct KeychainSessionStorage: SessionStorage {
    private let keychain: Keychain
    private static let account = "session"

    public init(service: String) {
        keychain = Keychain(service: service)
    }

    public func save(_ session: Session) async -> TainaResult<Void> {
        guard let data = try? APICoding.encoder.encode(session) else {
            return .failure(.invalidResponse("session could not be encoded"))
        }
        return keychain.set(data, account: Self.account)
    }

    public func load() async -> TainaResult<Session?> {
        switch keychain.get(account: Self.account) {
        case .success(nil):
            return .success(nil)
        case .success(.some(let data)):
            return APICoding.decoder.decode(Session.self, from: data, label: "stored session").map { Optional($0) }
        case .failure(let error):
            return .failure(error)
        }
    }

    public func clear() async -> TainaResult<Void> {
        keychain.remove(account: Self.account)
    }
}

/// In memory storage for tests and previews. Seeding it starts from a
/// session instead of a login.
public actor InMemorySessionStorage: SessionStorage {
    private var stored: Session?

    public init(_ session: Session? = nil) {
        stored = session
    }

    public func save(_ session: Session) async -> TainaResult<Void> {
        stored = session
        return .success(())
    }

    public func load() async -> TainaResult<Session?> {
        .success(stored)
    }

    public func clear() async -> TainaResult<Void> {
        stored = nil
        return .success(())
    }
}
