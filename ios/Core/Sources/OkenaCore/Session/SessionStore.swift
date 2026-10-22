import Foundation

/// One session, visible to every caller at once: one actor instead of a
/// lock or a singleton. `LiveTainaAPI` reads the token at call time, so a
/// revoked token fails on the next request.
public actor SessionStore {
    private var session: Session?
    private let storage: SessionStorage

    public init(storage: SessionStorage) {
        self.storage = storage
        session = nil
    }

    /// Loads the stored session into memory. Idempotent.
    public func restore() async -> TainaResult<Session?> {
        let loaded = await storage.load()
        if case .success(let value) = loaded {
            session = value
        }
        return loaded
    }

    public func signIn(_ session: Session) async -> TainaResult<Void> {
        let saved = await storage.save(session)
        if case .success = saved {
            self.session = session
        }
        return saved
    }

    /// Clears storage and memory. Leaving is local: a stored token the
    /// server has already forgotten is worse than either.
    public func signOut() async -> TainaResult<Void> {
        let cleared = await storage.clear()
        session = nil
        return cleared
    }

    public func current() async -> Session? {
        session
    }

    public func token() async -> String? {
        session?.token
    }

    /// Updates the identity and re-saves, so a role change or a renamed
    /// community survives a relaunch. The device record stays as stored.
    public func refreshIdentity(_ me: Me) async -> TainaResult<Void> {
        guard let current = session else {
            return .failure(.notSignedIn)
        }
        let updated = Session(token: current.token, device: current.device, me: me.ava, tekoa: me.tekoa)
        let saved = await storage.save(updated)
        if case .success = saved {
            session = updated
        }
        return saved
    }
}
