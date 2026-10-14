import Foundation
import Testing

@testable import OkenaCore

private let sessionJSON = """
{"token":"tnd_abcdef0123456789abcdef0123456789","device":{"public_id":"devp2xw5m8q3","name":"iPhone da Ana","last_used_at":null,"revoked_at":null,"created_at":"2026-10-14T08:00:00Z"},"me":{"public_id":"avap2xw5m8q3","username":"ana","display_name":"Ana Souza","papel":"zelador","activated_at":"2026-02-01T09:00:00Z","deactivated_at":null,"created_at":"2026-02-01T09:00:00Z"},"tekoa":{"public_id":"tekp2xw5m8q3","name":"Tekoa Sapukai","domain":"taina.sapukai.ts.net","storage_quota_bytes":268435456000,"storage_used_bytes":1832110000,"created_at":"2026-02-01T09:00:00Z"}}
"""

private func fixturedSession() throws -> Session {
    try #require(APICoding.decoder.decode(Session.self, from: Data(sessionJSON.utf8), label: "session fixture").value)
}

@Test func sessionRoundTripsThroughInMemoryStorage() async throws {
    let session = try fixturedSession()
    let storage = InMemorySessionStorage()
    let store = SessionStore(storage: storage)

    #expect(await store.token() == nil)

    #expect(await store.signIn(session).value != nil)
    #expect(await store.token() == session.token)
    #expect(await store.current()?.me.username == "ana")

    // A fresh store over the same storage sees the same session.
    let restored = try #require(await SessionStore(storage: storage).restore().value)
    #expect(restored == session)
}

@Test func restoreLoadsAStoredSession() async throws {
    let session = try fixturedSession()
    let store = SessionStore(storage: InMemorySessionStorage(session))

    let restored = try #require(await store.restore().value)
    #expect(restored == session)
    #expect(await store.token() == session.token)
}

@Test func tokenIsNilBeforeSignInAndAfterSignOut() async throws {
    let session = try fixturedSession()
    let storage = InMemorySessionStorage()
    let store = SessionStore(storage: storage)

    #expect(await store.token() == nil)

    #expect(await store.signIn(session).value != nil)
    #expect(await store.signOut().value != nil)
    #expect(await store.token() == nil)
    #expect(await store.current() == nil)
    #expect(try await storage.load().get() == nil)
}

@Test func refreshIdentityReplacesMeAndResaves() async throws {
    let session = try fixturedSession()
    let storage = InMemorySessionStorage()
    let store = SessionStore(storage: storage)
    #expect(await store.signIn(session).value != nil)

    let renamed = Ava(
        publicId: session.me.publicId,
        username: "ana",
        displayName: "Ana S.",
        papel: .morador,
        activatedAt: session.me.activatedAt,
        deactivatedAt: nil,
        createdAt: session.me.createdAt
    )
    #expect(await store.refreshIdentity(Me(ava: renamed, tekoa: session.tekoa, device: session.device)).value != nil)

    let current = try #require(await store.current())
    #expect(current.me.displayName == "Ana S.")
    #expect(current.me.papel == .morador)
    #expect(current.token == session.token)
    #expect(current.device == session.device)

    // The change survives a relaunch: it is in storage too.
    guard case .success(.some(let stored)) = await storage.load() else {
        #expect(Bool(false), "expected a stored session")
        return
    }
    #expect(stored.me.displayName == "Ana S.")
}

@Test func refreshIdentityWithoutASessionIsNotSignedIn() async {
    let store = SessionStore(storage: InMemorySessionStorage())
    #expect(await store.refreshIdentity(Me(ava: .init(publicId: "avap2xw5m8q3", username: "ana", displayName: nil, papel: .morador, activatedAt: nil, deactivatedAt: nil, createdAt: "2026-02-01T09:00:00Z"), tekoa: .init(publicId: "tekp2xw5m8q3", name: "Tekoa Sapukai", domain: "taina.sapukai.ts.net", storageQuotaBytes: nil, storageUsedBytes: 0, createdAt: "2026-02-01T09:00:00Z"), device: nil)).error == .notSignedIn)
}
