import Foundation

/// The real caller: a `Transport`, the box address from `HostStore` and the
/// device token from `SessionStore`, both read at call time. A revoked
/// token must fail on the next request, so reading late is the point.
public struct LiveTainaAPI: TainaAPI {
    private let transport: Transport
    private let host: HostStore
    private let session: SessionStore

    public init(
        transport: Transport = URLSessionTransport(),
        host: HostStore,
        session: SessionStore
    ) {
        self.transport = transport
        self.host = host
        self.session = session
    }

    public func instance() async -> TainaResult<Instance> {
        await prepared(path: "instance", authenticated: false).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Instance.self, label: "instance")
            }
        }
    }

    public func createSession(username: String, password: String, deviceName: String) async -> TainaResult<Session> {
        struct Login: Encodable {
            let username: String
            let password: String
            let deviceName: String
        }

        guard let body = try? APICoding.encoder.encode(Login(username: username, password: password, deviceName: deviceName)) else {
            return .failure(.invalidResponse("login body"))
        }
        return await prepared(path: "session", method: "POST", body: body, contentType: "application/json", authenticated: false)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, Session.self, label: "session")
                }
            }
    }

    public func inviteStatus(token: String) async -> TainaResult<TokenStatus> {
        await prepared(path: "invites/\(token)", authenticated: false).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, TokenStatus.self, label: "invite status")
            }
        }
    }

    /// One password on the wire, on purpose: the two password fields are
    /// the app's own check, so a typo cannot arrive looking like a dead
    /// token (the 401 the box would answer otherwise).
    public func acceptInvite(token: String, username: String, password: String, displayName: String?, deviceName: String) async -> TainaResult<Session> {
        struct Accept: Encodable {
            let username: String
            let password: String
            let displayName: String?
            let deviceName: String
        }

        guard let body = try? APICoding.encoder.encode(Accept(username: username, password: password, displayName: displayName, deviceName: deviceName)) else {
            return .failure(.invalidResponse("invite accept body"))
        }
        return await prepared(path: "invites/\(token)/accept", method: "POST", body: body, contentType: "application/json", authenticated: false)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, Session.self, label: "accepted invite")
                }
            }
    }

    public func resetStatus(token: String) async -> TainaResult<TokenStatus> {
        await prepared(path: "password-resets/\(token)", authenticated: false).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, TokenStatus.self, label: "reset status")
            }
        }
    }

    public func resetPassword(token: String, password: String, deviceName: String) async -> TainaResult<Session> {
        struct Reset: Encodable {
            let password: String
            let deviceName: String
        }

        guard let body = try? APICoding.encoder.encode(Reset(password: password, deviceName: deviceName)) else {
            return .failure(.invalidResponse("password reset body"))
        }
        return await prepared(path: "password-resets/\(token)", method: "POST", body: body, contentType: "application/json", authenticated: false)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, Session.self, label: "password reset")
                }
            }
    }

    public func revokeSession() async -> TainaResult<Void> {
        await prepared(path: "session", method: "DELETE", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respondEmpty(http)
            }
        }
    }

    public func me() async -> TainaResult<Me> {
        await prepared(path: "me", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Me.self, label: "me")
            }
        }
    }

    public func devices() async -> TainaResult<[DeviceToken]> {
        await prepared(path: "devices", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                await self.respond(http, Page<DeviceToken>.self, label: "devices").then { page in
                    .success(page.items)
                }
            }
        }
    }

    public func revokeDevice(id: String) async -> TainaResult<Void> {
        await prepared(path: "devices/\(id)", method: "DELETE", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respondEmpty(http)
            }
        }
    }

    public func listFolders() async -> TainaResult<[Folder]> {
        await prepared(path: "folders", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                await self.respond(http, Page<Folder>.self, label: "folders").then { page in
                    .success(page.items)
                }
            }
        }
    }

    public func folder(rkey: String) async -> TainaResult<Folder> {
        await prepared(path: "folders/\(rkey)", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Folder.self, label: "folder")
            }
        }
    }

    public func updateFolder(rkey: String, name: String?, zona: Zona?) async -> TainaResult<Folder> {
        struct Patch: Encodable {
            let name: String?
            let zona: Zona?
        }

        guard let body = try? APICoding.encoder.encode(Patch(name: name, zona: zona)) else {
            return .failure(.invalidResponse("folder patch body"))
        }
        return await prepared(path: "folders/\(rkey)", method: "PATCH", body: body, contentType: "application/json", authenticated: true)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, Folder.self, label: "folder")
                }
            }
    }

    public func moveFolder(rkey: String, parentRkey: String?) async -> TainaResult<Folder> {
        struct Move: Encodable {
            let parentRkey: String?
        }

        guard let body = try? APICoding.encoder.encode(Move(parentRkey: parentRkey)) else {
            return .failure(.invalidResponse("folder move body"))
        }
        return await prepared(path: "folders/\(rkey)/move", method: "POST", body: body, contentType: "application/json", authenticated: true)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, Folder.self, label: "folder")
                }
            }
    }

    public func deleteFolder(rkey: String) async -> TainaResult<Void> {
        await prepared(path: "folders/\(rkey)", method: "DELETE", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respondEmpty(http)
            }
        }
    }

    public func createFolder(name: String, parentRkey: String?) async -> TainaResult<Folder> {
        struct NewFolder: Encodable {
            let name: String
            let parentRkey: String?
        }

        guard let body = try? APICoding.encoder.encode(NewFolder(name: name, parentRkey: parentRkey)) else {
            return .failure(.invalidResponse("folder body"))
        }
        return await prepared(path: "folders", method: "POST", body: body, contentType: "application/json", authenticated: true)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, Folder.self, label: "folder")
                }
            }
    }

    public func folderContents(folderRkey: String?, limit: Int?, cursor: String?, sort: Sort?) async -> TainaResult<FolderContents> {
        let query: [String: String?] = [
            "folder": folderRkey,
            "limit": limit.map(String.init),
            "cursor": cursor,
            "sort": sort?.wire,
        ]
        return await prepared(path: "contents", query: query, authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, FolderContents.self, label: "contents")
            }
        }
    }

    public func upload(fileAt fileURL: URL, name: String, mime: String, folderRkey: String?) async -> TainaResult<File> {
        let boundary = MultipartBody.boundary()
        var parts: [MultipartBody.Part] = []
        if let folderRkey {
            parts.append(MultipartBody.Part(name: "folder", content: .text(folderRkey)))
        }
        parts.append(MultipartBody.Part(name: "file", filename: name, contentType: mime, content: .file(fileURL)))

        return await prepared(
            path: "files",
            method: "POST",
            contentType: "multipart/form-data; boundary=\(boundary)",
            authenticated: true
        )
        .then { request in
            await self.assemble(boundary: boundary, parts: parts, source: fileURL).then { bodyFile in
                let outcome = await self.transport.upload(request, fromFile: bodyFile)
                // Cleanup is best effort; the OS clears the temp directory.
                try? FileManager.default.removeItem(at: bodyFile)
                return await outcome.then { http in
                    self.respond(http, File.self, label: "uploaded file")
                }
            }
        }
    }

    public func file(rkey: String) async -> TainaResult<File> {
        await prepared(path: "files/\(rkey)", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, File.self, label: "file")
            }
        }
    }

    public func updateFile(rkey: String, name: String?, zona: Zona?) async -> TainaResult<File> {
        struct Patch: Encodable {
            let name: String?
            let zona: Zona?
        }

        guard let body = try? APICoding.encoder.encode(Patch(name: name, zona: zona)) else {
            return .failure(.invalidResponse("file patch body"))
        }
        return await prepared(path: "files/\(rkey)", method: "PATCH", body: body, contentType: "application/json", authenticated: true)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, File.self, label: "file")
                }
            }
    }

    public func moveFile(rkey: String, folderRkey: String?) async -> TainaResult<File> {
        // The wire key is `folder`, so the property carries the name itself;
        // `folderRkey` would encode as `folder_rkey`, which is not the key.
        struct Move: Encodable {
            let folder: String?
        }

        guard let body = try? APICoding.encoder.encode(Move(folder: folderRkey)) else {
            return .failure(.invalidResponse("file move body"))
        }
        return await prepared(path: "files/\(rkey)/move", method: "POST", body: body, contentType: "application/json", authenticated: true)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, File.self, label: "file")
                }
            }
    }

    public func deleteFile(rkey: String) async -> TainaResult<Void> {
        await prepared(path: "files/\(rkey)", method: "DELETE", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respondEmpty(http)
            }
        }
    }

    public func recent(limit: Int?) async -> TainaResult<Page<File>> {
        let query: [String: String?] = ["limit": limit.map(String.init)]
        return await prepared(path: "recent", query: query, authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Page<File>.self, label: "recent")
            }
        }
    }

    public func download(rkey: String) async -> TainaResult<URL> {
        await prepared(path: "files/\(rkey)/download", authenticated: true, accept: nil).then { request in
            await self.transport.download(request).then { http in
                self.settle(http, fallbackName: rkey)
            }
        }
    }

    public func thumbnail(rkey: String, size: ThumbnailSize) async -> TainaResult<Data> {
        // No type asked for, on purpose: the API pipeline negotiates JSON
        // only, so a request that says `Accept: image/webp` is answered 406
        // before the controller runs. The endpoint's type is fixed and
        // documented, so the client asks for anything.
        await prepared(path: "files/\(rkey)/thumbnail/\(size.rawValue)", authenticated: true, accept: "*/*")
            .then { request in
                await self.transport.send(request).then { http in
                    guard http.isSuccess else {
                        return .failure(Self.apiFailure(http))
                    }
                    return .success(http.data)
                }
            }
    }

    public func trash(limit: Int?, cursor: String?) async -> TainaResult<Page<File>> {
        let query: [String: String?] = [
            "limit": limit.map(String.init),
            "cursor": cursor,
        ]
        return await prepared(path: "trash", query: query, authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Page<File>.self, label: "trash")
            }
        }
    }

    public func restoreFile(rkey: String) async -> TainaResult<File> {
        await prepared(path: "trash/\(rkey)/restore", method: "POST", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, File.self, label: "restored file")
            }
        }
    }

    public func photos(limit: Int?, cursor: String?) async -> TainaResult<Page<File>> {
        let query: [String: String?] = [
            "limit": limit.map(String.init),
            "cursor": cursor,
        ]
        return await prepared(path: "photos", query: query, authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Page<File>.self, label: "photos")
            }
        }
    }

    public func photoTimeline(limit: Int?, cursor: String?) async -> TainaResult<Page<TimelineGroup>> {
        let query: [String: String?] = [
            "limit": limit.map(String.init),
            "cursor": cursor,
        ]
        return await prepared(path: "photos/timeline", query: query, authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Page<TimelineGroup>.self, label: "timeline")
            }
        }
    }

    public func accessTarget(fileRkey: String) async -> TainaResult<AccessTarget> {
        await prepared(path: "files/\(fileRkey)/access-target", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, AccessTarget.self, label: "access target")
            }
        }
    }

    public func requestAccess(fileRkey: String, motivo: String?) async -> TainaResult<Pedido> {
        struct Ask: Encodable {
            let motivo: String?
        }

        guard let body = try? APICoding.encoder.encode(Ask(motivo: motivo)) else {
            return .failure(.invalidResponse("access request body"))
        }
        return await prepared(path: "files/\(fileRkey)/access-request", method: "POST", body: body, contentType: "application/json", authenticated: true)
            .then { request in
                await self.transport.send(request).then { http in
                    self.respond(http, Pedido.self, label: "access request")
                }
            }
    }

    public func accessRequests() async -> TainaResult<Page<Pedido>> {
        await prepared(path: "access-requests", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Page<Pedido>.self, label: "access requests")
            }
        }
    }

    public func myRequests() async -> TainaResult<Page<Pedido>> {
        await prepared(path: "my-requests", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Page<Pedido>.self, label: "my requests")
            }
        }
    }

    public func approveRequest(id: String) async -> TainaResult<Concessao> {
        await prepared(path: "access-requests/\(id)/approve", method: "POST", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Concessao.self, label: "concessao")
            }
        }
    }

    public func denyRequest(id: String) async -> TainaResult<Pedido> {
        await prepared(path: "access-requests/\(id)/deny", method: "POST", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Pedido.self, label: "pedido")
            }
        }
    }

    public func mural(limit: Int?, cursor: String?) async -> TainaResult<Page<MuralEntry>> {
        let query: [String: String?] = [
            "limit": limit.map(String.init),
            "cursor": cursor,
        ]
        return await prepared(path: "mural", query: query, authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Page<MuralEntry>.self, label: "mural")
            }
        }
    }

    public func storage() async -> TainaResult<StorageStats> {
        await prepared(path: "storage", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, StorageStats.self, label: "storage")
            }
        }
    }

    public func saude() async -> TainaResult<Saude> {
        await prepared(path: "saude", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Saude.self, label: "saude")
            }
        }
    }

    public func members() async -> TainaResult<Page<Ava>> {
        await prepared(path: "members", authenticated: true).then { request in
            await self.transport.send(request).then { http in
                self.respond(http, Page<Ava>.self, label: "members")
            }
        }
    }

    // MARK: internals

    /// Reads the box address and, when authenticated, the token at call
    /// time. Without a saved address the caller is sent back to Setup.
    private func prepared(
        path: String,
        method: String = "GET",
        query: [String: String?] = [:],
        body: Data? = nil,
        contentType: String? = nil,
        authenticated: Bool,
        accept: String? = "application/json"
    ) async -> TainaResult<URLRequest> {
        guard let address = await host.address() else {
            return .failure(.invalidAddress(.empty))
        }
        var token: String?
        if authenticated {
            guard let current = await session.token() else {
                return .failure(.notSignedIn)
            }
            token = current
        }
        return Self.build(
            base: address.url,
            path,
            method: method,
            query: query,
            body: body,
            contentType: contentType,
            authenticated: authenticated,
            token: token,
            accept: accept
        )
    }

    /// Builds one request against the box. Pure, so the URL, the query
    /// encoding and the `Authorization: Bearer` header are proven by tests.
    /// `Authorization` is only added when authenticated, so `GET /instance`
    /// and `POST /session` carry no token.
    static func build(
        base: URL,
        _ path: String,
        method: String = "GET",
        query: [String: String?] = [:],
        body: Data? = nil,
        contentType: String? = nil,
        authenticated: Bool = false,
        token: String? = nil,
        accept: String? = "application/json"
    ) -> TainaResult<URLRequest> {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return .failure(.invalidURL(base.absoluteString))
        }
        var prefix = components.path
        if prefix.hasSuffix("/") {
            prefix.removeLast()
        }
        components.path = "\(prefix)/api/v1/\(path)"

        let given = query.compactMap { name, value in
            value.map { URLQueryItem(name: name, value: $0) }
        }
        if !given.isEmpty {
            components.queryItems = given.sorted { $0.name < $1.name }
        }

        guard let url = components.url else {
            return .failure(.invalidURL(base.absoluteString))
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }
        if authenticated, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body
        return .success(request)
    }

    /// The one place a status becomes a value: 2xx decodes, anything else
    /// becomes the error envelope. 402, 429 and 5xx are not special cased;
    /// the envelope carries `code` and the typed helpers on `APIError` are
    /// how a caller branches.
    private func respond<Value: Decodable>(_ http: HTTPResponse, _ type: Value.Type, label: String) -> TainaResult<Value> {
        guard http.isSuccess else {
            return .failure(Self.apiFailure(http))
        }
        return APICoding.decoder.decode(Value.self, from: http.data, label: label)
    }

    private func respondEmpty(_ http: HTTPResponse) -> TainaResult<Void> {
        guard http.isSuccess else {
            return .failure(Self.apiFailure(http))
        }
        return .success(())
    }

    /// Decodes the error envelope; when the body is not the envelope (an
    /// HTML error page, an empty body), the fallback is `internal_error` and
    /// the body never reaches the message.
    static func apiFailure(_ http: HTTPResponse) -> TainaError {
        struct Payload: Decodable {
            let code: String
            let message: String
            let details: [String: [String]]?
        }
        struct Envelope: Decodable {
            let error: Payload
        }

        let data = http.data.isEmpty
            ? http.fileURL.flatMap { try? Data(contentsOf: $0) } ?? Data()
            : http.data

        if let envelope = APICoding.decoder.decode(Envelope.self, from: data, label: "error envelope").value {
            return .api(APIError(
                code: envelope.error.code,
                status: http.status,
                message: envelope.error.message,
                details: envelope.error.details ?? [:]
            ))
        }
        return .api(APIError(
            code: "internal_error",
            status: http.status,
            message: "Algo deu errado na comunidade. Tente de novo em instantes.",
            details: [:]
        ))
    }

    /// Writes the multipart body to a temp file, streaming the source file
    /// through it, so a 2 GiB video is never held in memory.
    private func assemble(boundary: String, parts: [MultipartBody.Part], source: URL) async -> TainaResult<URL> {
        let bodyFile = FileManager.default.temporaryDirectory
            .appending(path: "taina-upload-" + UUID().uuidString)
        do {
            FileManager.default.createFile(atPath: bodyFile.path, contents: nil)
            let output = try FileHandle(forWritingTo: bodyFile)
            defer { try? output.close() }
            try output.write(contentsOf: MultipartBody.prologue(boundary: boundary, parts: parts))

            let input = try FileHandle(forReadingFrom: source)
            // One megabyte at a time: the source may be a 2 GiB video.
            while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
            }
            try input.close()

            try output.write(contentsOf: MultipartBody.epilogue(boundary: boundary))
            return .success(bodyFile)
        } catch {
            try? FileManager.default.removeItem(at: bodyFile)
            return .failure(.network("could not assemble the upload body: \(error.localizedDescription)"))
        }
    }

    /// Moves the downloaded file under a unique name: the server's
    /// content-disposition filename when it carries one, the rkey otherwise.
    private func settle(_ http: HTTPResponse, fallbackName: String) -> TainaResult<URL> {
        guard http.isSuccess, let file = http.fileURL else {
            // The failure reads the envelope from the file, so the file goes
            // away only after the failure is built.
            let failure = Self.apiFailure(http)
            if let file = http.fileURL {
                try? FileManager.default.removeItem(at: file)
            }
            return .failure(failure)
        }

        let name = Self.attachmentFilename(in: http) ?? fallbackName
        // The uniqueness goes in the directory, not in the filename: the
        // person reads this name in the share sheet and in Files.
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "taina-download-" + UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appending(path: Self.sanitize(name))
            try FileManager.default.moveItem(at: file, to: target)
            return .success(target)
        } catch {
            try? FileManager.default.removeItem(at: file)
            return .failure(.network("could not keep the downloaded file: \(error.localizedDescription)"))
        }
    }

    /// The `filename=` parameter of a Content-Disposition header, or nil.
    static func attachmentFilename(in http: HTTPResponse) -> String? {
        guard let disposition = http.header("Content-Disposition") else {
            return nil
        }
        for piece in disposition.split(separator: ";") {
            let trimmed = piece.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("filename=") {
                let value = String(trimmed.dropFirst("filename=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Path separators are the ones that make a filename walk the tree.
    static func sanitize(_ name: String) -> String {
        let clean = name
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\\", with: "")
        return clean.isEmpty ? "arquivo" : clean
    }
}
