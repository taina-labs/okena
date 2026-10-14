import Foundation
import Testing

@testable import OkenaCore

private let instanceJSON = """
{"bootstrapped":true,"tekoa":{"public_id":"tekp2xw5m8q3","name":"Tekoa Sapukai","domain":"taina.sapukai.ts.net","storage_quota_bytes":268435456000,"storage_used_bytes":1832110000,"created_at":"2026-02-01T09:00:00Z"},"version":"0.6.0"}
"""

private let sessionJSON = """
{"token":"tnd_abcdef0123456789abcdef0123456789","device":{"public_id":"devp2xw5m8q3","name":"iPhone da Ana","last_used_at":null,"revoked_at":null,"created_at":"2026-10-14T08:00:00Z"},"me":{"public_id":"avap2xw5m8q3","username":"ana","display_name":"Ana Souza","papel":"zelador","activated_at":"2026-02-01T09:00:00Z","deactivated_at":null,"created_at":"2026-02-01T09:00:00Z"},"tekoa":{"public_id":"tekp2xw5m8q3","name":"Tekoa Sapukai","domain":"taina.sapukai.ts.net","storage_quota_bytes":268435456000,"storage_used_bytes":1832110000,"created_at":"2026-02-01T09:00:00Z"}}
"""

private let contentsJSON = """
{"folders":[{"rkey":"3kx2n8pqrv5w2","cid":"bmq2a5xw7k3p9r2t8v4z6c1d5f7h9j2x","name":"Documentos da assembleia","zona":"casa","folder":null,"deleted_at":null,"created_at":"2026-03-10T14:00:00Z","updated_at":"2026-03-10T14:00:00Z"}],"items":[],"next_cursor":null}
"""

private let fileJSON = """
{"rkey":"3n4b9uxrw6a3","cid":"bp3q4r5s6t7u8v9w0x1y2z3a4b5c6d7e8","blob_cid":"bq4r5s6t7u8v9w0x1y2z3a4b5c6d7e8f9","sha256":"aa11bb22cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66","name":"ata.pdf","mime":"application/pdf","size":19,"zona":"casa","folder":"3kx2n8pqrv5w2","deleted_at":null,"created_at":"2026-10-14T08:00:00Z","updated_at":"2026-10-14T08:00:00Z"}
"""

private func fixturedSession() throws -> Session {
    try #require(APICoding.decoder.decode(Session.self, from: Data(sessionJSON.utf8), label: "session fixture").value)
}

private func boxAddress() throws -> InstanceAddress {
    try #require(InstanceAddress.parse(input: "https://box").value)
}

/// An API over a stub, with a saved address and a signed in session.
private func signedInAPI(
    answer: @escaping @Sendable (Call) async -> TainaResult<HTTPResponse>
) async throws -> (LiveTainaAPI, StubTransport) {
    let stub = StubTransport(handler: answer)
    let store = SessionStore(storage: InMemorySessionStorage())
    #expect(await store.signIn(try fixturedSession()).value != nil)
    let api = LiveTainaAPI(transport: stub, host: InMemoryHostStore(try boxAddress()), session: store)
    return (api, stub)
}

@Test func buildProducesThePathAcceptAndNoToken() {
    let built = LiveTainaAPI.build(base: URL(string: "https://box")!, "instance")
    let request = built.value
    #expect(request?.url?.absoluteString == "https://box/api/v1/instance")
    #expect(request?.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request?.value(forHTTPHeaderField: "Accept") == "application/json")
}

@Test func buildEncodesOnlyTheGivenQueryKeys() {
    let full = LiveTainaAPI.build(
        base: URL(string: "https://box")!,
        "contents",
        query: [
            "folder": "3kx2n8pqrv5w2",
            "limit": "100",
            "cursor": "abc",
            "sort": "date_desc",
        ]
    ).value
    #expect(full?.url?.query == "cursor=abc&folder=3kx2n8pqrv5w2&limit=100&sort=date_desc")

    let bare = LiveTainaAPI.build(
        base: URL(string: "https://box")!,
        "contents",
        query: ["folder": nil, "limit": nil, "cursor": nil, "sort": nil]
    ).value
    #expect(bare?.url?.absoluteString == "https://box/api/v1/contents")
}

@Test func instanceBuildsTheURLSendsNoTokenAndDecodes() async throws {
    let stub = StubTransport { _ in
        .success(http(URL(string: "https://box/api/v1/instance"), 200, body: instanceJSON))
    }
    let store = SessionStore(storage: InMemorySessionStorage())
    let api = LiveTainaAPI(transport: stub, host: InMemoryHostStore(try boxAddress()), session: store)

    let instance = try #require(await api.instance().value)
    #expect(instance.bootstrapped)
    #expect(instance.tekoa?.name == "Tekoa Sapukai")
    #expect(instance.version == "0.6.0")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.absoluteString == "https://box/api/v1/instance")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
}

@Test func createSessionPostsTheJSONAndReturnsTheRawToken() async throws {
    let stub = StubTransport { _ in
        .success(http(URL(string: "https://box/api/v1/session"), 201, body: sessionJSON))
    }
    let store = SessionStore(storage: InMemorySessionStorage())
    let api = LiveTainaAPI(transport: stub, host: InMemoryHostStore(try boxAddress()), session: store)

    let session = try #require(await api.createSession(username: "ana", password: "segredo", deviceName: "iPhone da Ana").value)
    #expect(session.token == "tnd_abcdef0123456789abcdef0123456789")
    #expect(session.me.username == "ana")
    #expect(session.tekoa.name == "Tekoa Sapukai")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body.contains("\"username\":\"ana\""))
    #expect(body.contains("\"password\":\"segredo\""))
    #expect(body.contains("\"device_name\":\"iPhone da Ana\""))
}

@Test func folderContentsQueriesOnlyWhatIsGiven() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/contents"), 200, body: contentsJSON))
    })

    let full = await api.folderContents(folderRkey: "3kx2n8pqrv5w2", limit: 100, cursor: "abc", sort: Sort(key: .date, direction: .desc))
    #expect(full.value != nil)
    let requests = await stub.recorder.requests()
    #expect(requests.count == 1)
    #expect(try #require(requests.first).url?.query == "cursor=abc&folder=3kx2n8pqrv5w2&limit=100&sort=date_desc")
}

@Test func folderContentsOmitsAbsentQueryKeys() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/contents"), 200, body: contentsJSON))
    })

    let bare = await api.folderContents(folderRkey: nil, limit: nil, cursor: nil, sort: nil)
    #expect(bare.value != nil)
    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.absoluteString == "https://box/api/v1/contents")
    #expect(request.url?.query == nil)
}

@Test func authenticatedCallCarriesTheBearerToken() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/me"), 200, body: "{}"))
    })

    _ = await api.me()

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tnd_abcdef0123456789abcdef0123456789")
}

@Test func unauthorizedEnvelopeBecomesTheTypedError() async throws {
    let body = """
    {"error":{"code":"not_authenticated","message":"Entre na sua conta para continuar."}}
    """
    let (api, _) = try await signedInAPI(answer: { _ in
        .success(http(nil, 401, body: body))
    })

    guard case .api(let apiError) = await api.me().error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.code == "not_authenticated")
    #expect(apiError.isUnauthorized)
    #expect(apiError.message == "Entre na sua conta para continuar.")
    #expect(apiError.details.isEmpty)
}

@Test func validationEnvelopeKeepsTheFieldDetails() async throws {
    let body = """
    {"error":{"code":"validation_failed","message":"Não foi possível criar a pasta.","details":{"nome":["não pode ficar em branco"]}}}
    """
    let (api, _) = try await signedInAPI(answer: { _ in
        .success(http(nil, 422, body: body))
    })

    guard case .api(let apiError) = await api.createFolder(name: "", parentRkey: nil).error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isValidationFailed)
    #expect(apiError.details["nome"] == ["não pode ficar em branco"])
    #expect(apiError.fieldMessages == ["não pode ficar em branco"])
}

@Test func nonJSONErrorBodyBecomesInternalErrorWithoutLeakingTheBody() async throws {
    let (api, _) = try await signedInAPI(answer: { _ in
        .success(http(nil, 500, body: "<html>boom tnd_secret</html>"))
    })

    guard case .api(let apiError) = await api.me().error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.code == "internal_error")
    #expect(apiError.status == 500)
    #expect(!apiError.message.contains("boom"))
    #expect(!apiError.message.contains("tnd_secret"))
}

@Test func the204OfRevokeSessionIsSuccess() async throws {
    let (api, _) = try await signedInAPI(answer: { _ in
        .success(http(nil, 204))
    })

    #expect(await api.revokeSession().value != nil)
}

@Test func aTransportFailureIsNetwork() async throws {
    let (api, _) = try await signedInAPI(answer: { _ in
        .failure(.network("offline"))
    })

    #expect(await api.me().error == .network("offline"))
}

@Test func uploadStreamsTheBodyAndCleansTheTempFile() async throws {
    actor Spy {
        var request: URLRequest?
        var bodyFile: URL?
        var body: Data?

        func saw(request: URLRequest, bodyFile: URL, body: Data) {
            self.request = request
            self.bodyFile = bodyFile
            self.body = body
        }
    }

    let source = FileManager.default.temporaryDirectory
        .appending(path: "upload-source-\(UUID().uuidString).bin")
    try Data("CONTEUDO-DO-ARQUIVO".utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }

    let spy = Spy()
    let (api, _) = try await signedInAPI(answer: { call in
        guard case .upload(let request, let bodyFile) = call else {
            return .failure(.invalidResponse("expected an upload"))
        }
        await spy.saw(request: request, bodyFile: bodyFile, body: (try? Data(contentsOf: bodyFile)) ?? Data())
        return .success(http(URL(string: "https://box/api/v1/files"), 201, body: fileJSON))
    })

    let uploaded = try #require(await api.upload(fileAt: source, name: "ata.pdf", mime: "application/pdf", folderRkey: "3kx2n8pqrv5w2").value)
    #expect(uploaded.name == "ata.pdf")

    let (request, bodyFile, body) = await (spy.request, spy.bodyFile, spy.body)
    let requestFinally = try #require(request)
    let bodyFileFinally = try #require(bodyFile)
    let bodyFinally = try #require(body)

    let contentType = try #require(requestFinally.value(forHTTPHeaderField: "Content-Type"))
    #expect(contentType.hasPrefix("multipart/form-data; boundary="))
    let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))

    let text = String(decoding: bodyFinally, as: UTF8.self)
    #expect(text.hasPrefix("--\(boundary)\r\n"))
    #expect(text.contains("Content-Disposition: form-data; name=\"folder\"\r\n\r\n3kx2n8pqrv5w2\r\n"))
    #expect(text.contains("; filename=\"ata.pdf\"\r\n"))
    #expect(text.contains("Content-Type: application/pdf\r\n"))
    #expect(text.hasSuffix("CONTEUDO-DO-ARQUIVO\r\n--\(boundary)--\r\n"))

    #expect(!FileManager.default.fileExists(atPath: bodyFileFinally.path))
}

@Test func uploadStillCleansTheTempFileWhenTheServerFails() async throws {
    let source = FileManager.default.temporaryDirectory
        .appending(path: "upload-source-\(UUID().uuidString).bin")
    try Data("BYTES".utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }

    let (api, _) = try await signedInAPI(answer: { call in
        guard case .upload(_, let bodyFile) = call else {
            return .failure(.invalidResponse("expected an upload"))
        }
        // The temp body file exists while the request is in flight.
        try? FileManager.default.removeItem(at: bodyFile)
        return .success(http(nil, 409, body: "{\"error\":{\"code\":\"storage_quota_exceeded\",\"message\":\"O cofre da comunidade encheu.\"}}"))
    })

    guard case .api(let apiError) = await api.upload(fileAt: source, name: "ata.pdf", mime: "application/pdf", folderRkey: nil).error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isQuotaExceeded)
}

@Test func downloadNamesTheFileFromContentDisposition() async throws {
    let stubFile = FileManager.default.temporaryDirectory
        .appending(path: "stub-download-\(UUID().uuidString)")
    try Data("BYTES-DO-RELATORIO".utf8).write(to: stubFile)

    let (api, _) = try await signedInAPI(answer: { _ in
        .success(http(
            URL(string: "https://box/api/v1/files/3m2a8twqpv5z2/download"),
            200,
            headers: ["Content-Disposition": "attachment; filename=\"relatorio anual.pdf\""],
            fileURL: stubFile
        ))
    })

    let url = try #require(await api.download(rkey: "3m2a8twqpv5z2").value)
    #expect(url.lastPathComponent == "relatorio anual.pdf")
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(try String(contentsOf: url, encoding: .utf8) == "BYTES-DO-RELATORIO")
    #expect(!FileManager.default.fileExists(atPath: stubFile.path))
}

@Test func downloadFallsBackToTheRkeyWithoutAHeader() async throws {
    let stubFile = FileManager.default.temporaryDirectory
        .appending(path: "stub-download-\(UUID().uuidString)")
    try Data("BYTES".utf8).write(to: stubFile)

    let (api, _) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/files/3m2a8twqpv5z2/download"), 200, fileURL: stubFile))
    })

    let url = try #require(await api.download(rkey: "3m2a8twqpv5z2").value)
    #expect(url.lastPathComponent == "3m2a8twqpv5z2")
}

@Test func downloadStripsPathSeparatorsFromTheServerName() async throws {
    let stubFile = FileManager.default.temporaryDirectory
        .appending(path: "stub-download-\(UUID().uuidString)")
    try Data("BYTES".utf8).write(to: stubFile)

    let (api, _) = try await signedInAPI(answer: { _ in
        .success(http(
            URL(string: "https://box/api/v1/files/3m2a8twqpv5z2/download"),
            200,
            headers: ["Content-Disposition": "attachment; filename=\"../../../etc/motd\""],
            fileURL: stubFile
        ))
    })

    let url = try #require(await api.download(rkey: "3m2a8twqpv5z2").value)
    #expect(!url.path.contains("/etc/"))
    #expect(url.lastPathComponent == "......etcmotd")
}
