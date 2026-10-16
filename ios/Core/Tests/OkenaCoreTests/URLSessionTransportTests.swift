import Foundation
import Synchronization
import Testing

@testable import OkenaCore

/// A URLProtocol that answers every request with fixed status, headers and
/// body, so the real URLSession paths are exercised without a socket.
final class StubURLProtocol: URLProtocol {
    struct State: Sendable {
        var status = 200
        var headers: [String: String] = [:]
        var body = Data()
    }

    static let state = Mutex(State())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let state = Self.state.withLock { $0 }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: state.status,
            httpVersion: "HTTP/1.1",
            headerFields: state.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: state.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func stubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func stubbedAddress() throws -> InstanceAddress {
    try #require(InstanceAddress.parse(input: "https://unit.test").value)
}

@Suite(.serialized)
    private struct URLSessionTransportTests {
        @Test func sendCarriesTheStatusAndTheBody() async throws {
        StubURLProtocol.state.withLock {
            $0.status = 201
            $0.body = Data("criado".utf8)
            $0.headers = [:]
        }
        let transport = URLSessionTransport(session: stubbedSession())

        let response = try #require(await transport.send(URLRequest(url: URL(string: "https://unit.test/x")!)).value)
        #expect(response.status == 201)
        #expect(response.isSuccess)
        #expect(response.body == "criado")
        #expect(response.fileURL == nil)
    }

    @Test func uploadCarriesTheStatusAndTheBody() async throws {
        StubURLProtocol.state.withLock {
            $0.status = 200
            $0.body = Data("ok".utf8)
        }
        let transport = URLSessionTransport(session: stubbedSession())
        let file = FileManager.default.temporaryDirectory.appending(path: "urlsession-transport-\(UUID().uuidString)")
        try Data("BYTES".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let response = try #require(await transport.upload(URLRequest(url: URL(string: "https://unit.test/x")!), fromFile: file).value)
        #expect(response.status == 200)
        #expect(response.body == "ok")
    }

    @Test func downloadPutsTheBodyInAFileAndKeepsTheHeaders() async throws {
        StubURLProtocol.state.withLock {
            $0.status = 200
            $0.body = Data("BYTES".utf8)
            $0.headers = ["Content-Disposition": "attachment; filename=\"a.pdf\""]
        }
        let transport = URLSessionTransport(session: stubbedSession())

        let response = try #require(await transport.download(URLRequest(url: URL(string: "https://unit.test/x")!)).value)
        let file = try #require(response.fileURL)
        #expect(response.status == 200)
        #expect(response.data.isEmpty)
        // The header lookup is case-insensitive.
        #expect(response.header("content-DISPOSITION") == "attachment; filename=\"a.pdf\"")
        #expect(try Data(contentsOf: file) == Data("BYTES".utf8))
        try? FileManager.default.removeItem(at: file)
    }

    @Test func downloadOfAnErrorKeepsTheResponseForTheCaller() async throws {
        StubURLProtocol.state.withLock {
            $0.status = 401
            $0.body = Data("{\"error\":{\"code\":\"not_authenticated\",\"message\":\"Entre na sua conta para continuar.\"}}".utf8)
            $0.headers = [:]
        }
        let transport = URLSessionTransport(session: stubbedSession())

        let response = try #require(await transport.download(URLRequest(url: URL(string: "https://unit.test/x")!)).value)
        #expect(response.status == 401)
        #expect(!response.isSuccess)
        try? FileManager.default.removeItem(at: try #require(response.fileURL))
    }

    @Test func downloadErrorEnvelopeBecomesTheTypedError() async throws {
        StubURLProtocol.state.withLock {
            $0.status = 401
            $0.body = Data("{\"error\":{\"code\":\"not_authenticated\",\"message\":\"Entre na sua conta para continuar.\"}}".utf8)
        }
        let store = SessionStore(storage: InMemorySessionStorage())
        #expect(await store.signIn(try fixturedSession()).value != nil)
        let api = LiveTainaAPI(
            transport: URLSessionTransport(session: stubbedSession()),
            host: InMemoryHostStore(try stubbedAddress()),
            session: store
        )

        guard case .api(let apiError) = await api.download(rkey: "3m2a8twqpv5z2").error else {
            #expect(Bool(false), "expected .api")
            return
        }
        #expect(apiError.isUnauthorized)
        #expect(apiError.code == "not_authenticated")
    }

    private func fixturedSession() throws -> Session {
        let json = """
        {"token":"tnd_abcdef0123456789abcdef0123456789","device":{"public_id":"devp2xw5m8q3","name":"iPhone da Ana","last_used_at":null,"revoked_at":null,"created_at":"2026-10-14T08:00:00Z"},"me":{"public_id":"avap2xw5m8q3","username":"ana","display_name":"Ana Souza","papel":"zelador","activated_at":"2026-02-01T09:00:00Z","deactivated_at":null,"created_at":"2026-02-01T09:00:00Z"},"tekoa":{"public_id":"tekp2xw5m8q3","name":"Tekoa Sapukai","domain":"taina.sapukai.ts.net","storage_quota_bytes":268435456000,"storage_used_bytes":1832110000,"created_at":"2026-02-01T09:00:00Z"}}
        """
        return try #require(APICoding.decoder.decode(Session.self, from: Data(json.utf8), label: "session fixture").value)
    }
}
