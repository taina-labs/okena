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

private let folderJSON = """
{"rkey":"3kx2n8pqrv5w2","cid":"bmq2a5xw7k3p9r2t8v4z6c1d5f7h9j2x","name":"Documentos da assembleia","zona":"casa","folder":null,"deleted_at":null,"created_at":"2026-03-10T14:00:00Z","updated_at":"2026-03-10T14:00:00Z"}
"""

private let updatedFolderJSON = """
{"rkey":"3kx2n8pqrv5w2","cid":"bmq2a5xw7k3p9r2t8v4z6c1d5f7h9j2x","name":"Atas publicadas","zona":"praca","folder":null,"deleted_at":null,"created_at":"2026-03-10T14:00:00Z","updated_at":"2026-10-14T09:00:00Z"}
"""

private let fotoJSON = """
{"rkey":"3m7d1wyzr4c8u","cid":"bt6u7v8w9x0y1z2a3b4c5d6e7f8g9h0i1","blob_cid":"bu7v8w9x0y1z2a3b4c5d6e7f8g9h0i1j2","sha256":"cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66aa11bb22","name":"Foto da quadra.jpg","mime":"image/jpeg","size":1204331,"zona":"praca","folder":null,"deleted_at":null,"created_at":"2026-06-21T21:12:00Z","updated_at":"2026-06-21T21:12:00Z"}
"""

private let filePageJSON = "{\"items\":[" + fileJSON + "],\"next_cursor\":\"12\"}"

private let anaJSON = """
{"public_id":"avap2xw5m8q3","username":"ana","display_name":"Ana Souza","papel":"zelador","activated_at":"2026-02-01T09:00:00Z","deactivated_at":null,"created_at":"2026-02-01T09:00:00Z"}
"""

private let joanaJSON = """
{"public_id":"avaq7r2m5xk9p1","username":"joana","display_name":"Joana Reis","papel":"morador","activated_at":"2026-02-02T09:00:00Z","deactivated_at":null,"created_at":"2026-02-02T09:00:00Z"}
"""

private let devicesPageJSON = """
{"items":[{"public_id":"devp2xw5m8q3","name":"iPhone da Ana","last_used_at":"2026-10-14T08:00:00Z","revoked_at":null,"created_at":"2026-10-14T08:00:00Z"}],"next_cursor":null}
"""

private let accessTargetJSON = """
{"owner":\(joanaJSON),"rkey":"3n4b9uxrw6a3","name":"ata.pdf"}
"""

private let pedidoJSON = """
{"public_id":"ped3xk9mq2v7w4","tipo":"leitura","recurso":"3n4b9uxrw6a3","motivo":"Preciso do estatuto para a reuniao de domingo.","status":"pendente","decidido_em":null,"created_at":"2026-10-12T10:00:00Z","pedinte":\(joanaJSON),"dono":\(anaJSON)}
"""

private let deniedPedidoJSON = """
{"public_id":"ped3xk9mq2v7w4","tipo":"leitura","recurso":"3n4b9uxrw6a3","motivo":"Preciso do estatuto para a reuniao de domingo.","status":"negado","decidido_em":"2026-10-14T12:00:00Z","created_at":"2026-10-12T10:00:00Z","pedinte":\(joanaJSON),"dono":\(anaJSON)}
"""

private let concessaoJSON = """
{"public_id":"con4kx9mq2v7w5","tipo":"leitura","recurso":"3n4b9uxrw6a3","concedida_em":"2026-10-14T12:00:00Z","revogada_em":null,"created_at":"2026-10-14T12:00:00Z","leitor":\(joanaJSON),"dono":\(anaJSON)}
"""

private let pedidosPageJSON = """
{"items":[\(pedidoJSON)],"next_cursor":null}
"""

private let storageJSON = """
{"used_bytes":1832110000,"quota_bytes":268435456000,"by_kind":{"photos":1100000000,"videos":600000000,"documents":132110000,"others":0},"files":42,"photos":30,"trash":{"count":3,"bytes":1000000}}
"""

private let saudeJSON = """
{"storage":\(storageJSON),"jobs":{"renditions":0,"backups":1},"backup":{"at":"2026-10-14T03:00:00Z","bytes":1829000000}}
"""

private let muralPageJSON = """
{"items":[{"seq":2,"tipo":"arquivo.publicado","payload":{"name":"Foto da quadra.jpg","zona":"praca","size":1204331,"featured":true,"caption":null,"tags":["festa","quadra"]},"cid":"bz8x6k4m2q9v1p3r5t7w2y4a6c8e0g2","prev":"by7w5j3l1p8u0o2q4s6v1x3z5a7d9f1","created_at":"2026-06-21T21:12:00Z"},{"seq":1,"tipo":"pasta.criada","payload":{"name":"Fotos da festa"},"cid":"by7w5j3l1p8u0o2q4s6v1x3z5a7d9f1","prev":null,"created_at":"2026-06-21T20:00:00Z"}],"next_cursor":null}
"""

private let timelinePageJSON = """
{"items":[{"date":"2026-06-21","photos":[\(fotoJSON)]}],"next_cursor":null}
"""

private let membersPageJSON = """
{"items":[\(anaJSON),\(joanaJSON)],"next_cursor":null}
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

/// The API pipeline negotiates JSON only (`plug :accepts, ["json"]`), so a
/// request that asks for `image/webp` is answered 406 before the controller
/// runs: found against a live box, where every thumbnail call came back as
/// `internal_error`. The client asks for anything instead.
@Test func thumbnailDoesNotAskForATypeThePipelineCannotNegotiate() async throws {
    let (api, stub) = try await signedInAPI { _ in
        .success(http(URL(string: "https://box/api/v1/files/3n4b9uxrw6a3/thumbnail/sm"), 200))
    }
    _ = await api.thumbnail(rkey: "3n4b9uxrw6a3", size: .sm)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.value(forHTTPHeaderField: "Accept") == "*/*")
    #expect(request.url?.absoluteString == "https://box/api/v1/files/3n4b9uxrw6a3/thumbnail/sm")
}

/// A file without a rendition is a body-less 404 on the box, not the
/// envelope. It still has to come back as an API error with the status, so a
/// screen can tell "no thumbnail" from "nothing answered".
@Test func thumbnailWithoutARenditionIsAnAPIErrorWithTheStatus() async throws {
    let (api, _) = try await signedInAPI { _ in
        .success(http(URL(string: "https://box/api/v1/files/3n4b9uxrw6a3/thumbnail/sm"), 404))
    }
    guard case .failure(.api(let error)) = await api.thumbnail(rkey: "3n4b9uxrw6a3", size: .sm) else {
        Issue.record("expected an API error for a body-less 404")
        return
    }
    #expect(error.status == 404)
}

@Test func buildProducesThePathAcceptAndNoToken() {    let built = LiveTainaAPI.build(base: URL(string: "https://box")!, "instance")
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

@Test func devicesDecodesThePageAndReturnsTheList() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/devices"), 200, body: devicesPageJSON))
    })

    let devices = try #require(await api.devices().value)
    #expect(devices.map(\.name) == ["iPhone da Ana"])
    #expect(devices.first?.revokedAt == nil)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.absoluteString == "https://box/api/v1/devices")
}

@Test func revokeDeviceSendsDeleteToTheDevicePath() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(nil, 204))
    })

    #expect(await api.revokeDevice(id: "devp2xw5m8q3").value != nil)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "DELETE")
    #expect(request.url?.absoluteString == "https://box/api/v1/devices/devp2xw5m8q3")
}

@Test func folderFetchesByRkey() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/folders/3kx2n8pqrv5w2"), 200, body: folderJSON))
    })

    let folder = try #require(await api.folder(rkey: "3kx2n8pqrv5w2").value)
    #expect(folder.name == "Documentos da assembleia")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "GET")
    #expect(request.url?.absoluteString == "https://box/api/v1/folders/3kx2n8pqrv5w2")
}

@Test func updateFolderPatchesNameAndZone() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/folders/3kx2n8pqrv5w2"), 200, body: updatedFolderJSON))
    })

    let folder = try #require(await api.updateFolder(rkey: "3kx2n8pqrv5w2", name: "Atas publicadas", zona: .praca).value)
    #expect(folder.name == "Atas publicadas")
    #expect(folder.zona == .praca)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "PATCH")
    #expect(request.url?.absoluteString == "https://box/api/v1/folders/3kx2n8pqrv5w2")
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body.contains("\"name\":\"Atas publicadas\""))
    #expect(body.contains("\"zona\":\"praca\""))
}

@Test func updateFileOmitsTheFieldsItWasNotGiven() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/files/3n4b9uxrw6a3"), 200, body: fileJSON))
    })

    _ = await api.updateFile(rkey: "3n4b9uxrw6a3", name: "ata renomeada.pdf", zona: nil)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "PATCH")
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body.contains("\"name\":\"ata renomeada.pdf\""))
    #expect(!body.contains("zona"))
}

@Test func moveFolderPostsParentRkey() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/folders/3kx2n8pqrv5w2/move"), 200, body: folderJSON))
    })

    _ = await api.moveFolder(rkey: "3kx2n8pqrv5w2", parentRkey: "3kz9t4mqc1h7d")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://box/api/v1/folders/3kx2n8pqrv5w2/move")
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body.contains("\"parent_rkey\":\"3kz9t4mqc1h7d\""))
}

@Test func movingAFolderToTheRootSendsAnEmptyObject() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/folders/3kx2n8pqrv5w2/move"), 200, body: folderJSON))
    })

    _ = await api.moveFolder(rkey: "3kx2n8pqrv5w2", parentRkey: nil)

    let request = try #require(await stub.recorder.requests().first)
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body == "{}")
}

@Test func moveFileUsesTheFolderWireKey() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/files/3n4b9uxrw6a3/move"), 200, body: fileJSON))
    })

    _ = await api.moveFile(rkey: "3n4b9uxrw6a3", folderRkey: "3kx2n8pqrv5w2")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://box/api/v1/files/3n4b9uxrw6a3/move")
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body.contains("\"folder\":\"3kx2n8pqrv5w2\""))
    #expect(!body.contains("folder_rkey"))
}

@Test func theDeletesOfFolderAndFileSendDeleteAndReadThe204() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(nil, 204))
    })

    #expect(await api.deleteFolder(rkey: "3kx2n8pqrv5w2").value != nil)
    #expect(await api.deleteFile(rkey: "3n4b9uxrw6a3").value != nil)

    let requests = await stub.recorder.requests()
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { $0.httpMethod == "DELETE" })
    #expect(requests.first?.url?.absoluteString == "https://box/api/v1/folders/3kx2n8pqrv5w2")
    #expect(requests.last?.url?.absoluteString == "https://box/api/v1/files/3n4b9uxrw6a3")
}

@Test func trashDecodesThePaginatedEnvelope() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/trash"), 200, body: filePageJSON))
    })

    let page = try #require(await api.trash(limit: 10, cursor: "12").value)
    #expect(page.items.map(\.name) == ["ata.pdf"])
    #expect(page.nextCursor == "12")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.query == "cursor=12&limit=10")
}

@Test func recentQueriesOnlyTheLimit() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/recent"), 200, body: filePageJSON))
    })

    _ = await api.recent(limit: 5)
    _ = await api.recent(limit: nil)

    let requests = await stub.recorder.requests()
    #expect(try #require(requests.first).url?.query == "limit=5")
    #expect(try #require(requests.last).url?.query == nil)
}

@Test func photosQueriesLimitAndCursor() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/photos"), 200, body: filePageJSON))
    })

    _ = await api.photos(limit: 50, cursor: "abc")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.path == "/api/v1/photos")
    #expect(request.url?.query == "cursor=abc&limit=50")
}

@Test func photoTimelineDecodesTheDaysAndQueriesThePage() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/photos/timeline"), 200, body: timelinePageJSON))
    })

    let page = try #require(await api.photoTimeline(limit: 20, cursor: nil).value)
    #expect(page.items.map(\.date) == ["2026-06-21"])
    #expect(page.items.first?.photos.map(\.name) == ["Foto da quadra.jpg"])

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.path == "/api/v1/photos/timeline")
    #expect(request.url?.query == "limit=20")
}

@Test func restoreFilePostsToTheTrashPathAndDecodesTheFile() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/trash/3n4b9uxrw6a3/restore"), 200, body: fileJSON))
    })

    let file = try #require(await api.restoreFile(rkey: "3n4b9uxrw6a3").value)
    #expect(file.name == "ata.pdf")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://box/api/v1/trash/3n4b9uxrw6a3/restore")
}

@Test func muralKeepsThePayloadWhole() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/mural"), 200, body: muralPageJSON))
    })

    let page = try #require(await api.mural(limit: nil, cursor: nil).value)
    #expect(page.items.count == 2)
    let payload = try #require(page.items.first?.payload)
    #expect(payload["name"] == .string("Foto da quadra.jpg"))
    #expect(payload["zona"] == .string("praca"))
    #expect(payload["size"] == .int(1204331))
    #expect(payload["featured"] == .bool(true))
    #expect(payload["caption"] == .null)
    #expect(payload["tags"] == .array([.string("festa"), .string("quadra")]))
    #expect(page.items.last?.prev == nil)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.query == nil)
}

@Test func accessTargetDecodesTheOwner() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/files/3n4b9uxrw6a3/access-target"), 200, body: accessTargetJSON))
    })

    let target = try #require(await api.accessTarget(fileRkey: "3n4b9uxrw6a3").value)
    #expect(target.owner.username == "joana")
    #expect(target.rkey == "3n4b9uxrw6a3")
    #expect(target.name == "ata.pdf")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.absoluteString == "https://box/api/v1/files/3n4b9uxrw6a3/access-target")
}

@Test func requestAccessPostsMotivoAndDecodesThePedido() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/files/3n4b9uxrw6a3/access-request"), 201, body: pedidoJSON))
    })

    let pedido = try #require(await api.requestAccess(fileRkey: "3n4b9uxrw6a3", motivo: "Para a reuniao.").value)
    #expect(pedido.status == .pendente)
    #expect(pedido.pedinte?.username == "joana")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://box/api/v1/files/3n4b9uxrw6a3/access-request")
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body.contains("\"motivo\":\"Para a reuniao.\""))
}

@Test func accessRequestsAndMyRequestsDecodePedidoPages() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/access-requests"), 200, body: pedidosPageJSON))
    })

    let received = try #require(await api.accessRequests().value)
    #expect(received.items.first?.publicId == "ped3xk9mq2v7w4")

    let sent = try #require(await api.myRequests().value)
    #expect(sent.nextCursor == nil)

    let requests = await stub.recorder.requests()
    #expect(try #require(requests.first).url?.absoluteString == "https://box/api/v1/access-requests")
    #expect(try #require(requests.last).url?.absoluteString == "https://box/api/v1/my-requests")
}

@Test func approveRequestDecodesTheConcessao() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/access-requests/ped3xk9mq2v7w4/approve"), 200, body: concessaoJSON))
    })

    let concessao = try #require(await api.approveRequest(id: "ped3xk9mq2v7w4").value)
    #expect(concessao.leitor?.username == "joana")
    #expect(concessao.recurso == "3n4b9uxrw6a3")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://box/api/v1/access-requests/ped3xk9mq2v7w4/approve")
}

@Test func denyRequestReturnsTheDecidedPedido() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/access-requests/ped3xk9mq2v7w4/deny"), 200, body: deniedPedidoJSON))
    })

    let pedido = try #require(await api.denyRequest(id: "ped3xk9mq2v7w4").value)
    #expect(pedido.status == .negado)
    #expect(pedido.decididoEm == "2026-10-14T12:00:00Z")

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.absoluteString == "https://box/api/v1/access-requests/ped3xk9mq2v7w4/deny")
}

@Test func storageDecodesTheStats() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/storage"), 200, body: storageJSON))
    })

    let stats = try #require(await api.storage().value)
    #expect(stats.usedBytes == 1_832_110_000)
    #expect(stats.quotaBytes == 268_435_456_000)
    #expect(stats.byKind.photos == 1_100_000_000)
    #expect(stats.byKind.documents == 132_110_000)
    #expect(stats.files == 42)
    #expect(stats.trash.count == 3)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.absoluteString == "https://box/api/v1/storage")
}

@Test func saudeDecodesThePanel() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/saude"), 200, body: saudeJSON))
    })

    let saude = try #require(await api.saude().value)
    #expect(saude.jobs["backups"] == 1)
    #expect(saude.backup.at == "2026-10-14T03:00:00Z")
    #expect(saude.storage.files == 42)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.absoluteString == "https://box/api/v1/saude")
}

@Test func membersDecodesThePage() async throws {
    let (api, stub) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/members"), 200, body: membersPageJSON))
    })

    let page = try #require(await api.members().value)
    #expect(page.items.map(\.username) == ["ana", "joana"])
    #expect(page.items.first?.papel == .zelador)

    let request = try #require(await stub.recorder.requests().first)
    #expect(request.url?.absoluteString == "https://box/api/v1/members")
}

/// A pending invite has no username yet: the box returns it with
/// `username: null`, so the roster must still decode and the row falls back
/// to the invite's own words (the web's `display_name/1`).
@Test func membersDecodesAPendingInviteWithNoUsername() async throws {
    let pending = """
    {"public_id":"avatk9x2m5qp7w","username":null,"display_name":null,"papel":"morador","activated_at":null,"deactivated_at":null,"created_at":"2026-10-13T09:00:00Z"}
    """
    let page = "{\"items\":[\(anaJSON),\(pending)],\"next_cursor\":null}"

    let (api, _) = try await signedInAPI(answer: { _ in
        .success(http(URL(string: "https://box/api/v1/members"), 200, body: page))
    })

    let decoded = try #require(await api.members().value)
    #expect(decoded.items.count == 2)
    #expect(decoded.items.last?.username == nil)
    #expect(decoded.items.last?.label == "Convite pendente")
}
