import Foundation

/// A `TainaAPI` over an in-memory world: the preview double and the UI test
/// double, and the reason a screen can be built and looked at without a box.
/// It never touches `Transport`, `HostStore` or `SessionStore`.
public actor FakeTainaAPI: TainaAPI {
    private let delay: Duration = .milliseconds(300)
    private var counter = 0

    private var tekoa: Tekoa
    private var folders: [Folder]
    private var files: [File]
    private var bytes: [String: Data]
    private var session: Session?

    public init() {
        tekoa = Tekoa(
            publicId: "tekp2xw5m8q3",
            name: "Tekoa Sapukai",
            domain: "taina.sapukai.ts.net",
            storageQuotaBytes: 268_435_456_000,
            storageUsedBytes: 1_832_110_000,
            createdAt: "2026-02-01T09:00:00Z"
        )

        let assembleia = "3kx2n8pqrv5w2"
        let festa = "3kz9t4mqc1h7d"
        folders = [
            Folder(
                rkey: assembleia,
                cid: "bmq2a5xw7k3p9r2t8v4z6c1d5f7h9j2x",
                name: "Documentos da assembleia",
                zona: .casa,
                folder: nil,
                deletedAt: nil,
                createdAt: "2026-03-10T14:00:00Z",
                updatedAt: "2026-03-10T14:00:00Z"
            ),
            Folder(
                rkey: festa,
                cid: "bnu8b6y9l4q1s3u0w6y8d3e6g9k2m5o1p",
                name: "Fotos da festa",
                zona: .praca,
                folder: nil,
                deletedAt: nil,
                createdAt: "2026-06-21T20:00:00Z",
                updatedAt: "2026-06-21T20:00:00Z"
            ),
        ]

        files = [
            File(
                rkey: "3m2a8twqpv5z2",
                cid: "bp3q4r5s6t7u8v9w0x1y2z3a4b5c6d7e8",
                blobCid: "bq4r5s6t7u8v9w0x1y2z3a4b5c6d7e8f9",
                sha256: "aa11bb22cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66",
                name: "Estatuto da associacao.pdf",
                mime: "application/pdf",
                size: 48_213,
                zona: .casa,
                folder: assembleia,
                deletedAt: nil,
                createdAt: "2026-03-11T09:30:00Z",
                updatedAt: "2026-03-11T09:30:00Z"
            ),
            File(
                rkey: "3m5c9vxyq2b7t",
                cid: "br4s5t6u7v8w9x0y1z2a3b4c5d6e7f8g9",
                blobCid: "bs5t6u7v8w9x0y1z2a3b4c5d6e7f8g9h0",
                sha256: "bb22cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66aa11",
                name: "Lista de presenca.pdf",
                mime: "application/pdf",
                size: 12_874,
                zona: .casa,
                folder: nil,
                deletedAt: nil,
                createdAt: "2026-04-02T16:45:00Z",
                updatedAt: "2026-04-02T16:45:00Z"
            ),
            File(
                rkey: "3m7d1wyzr4c8u",
                cid: "bt6u7v8w9x0y1z2a3b4c5d6e7f8g9h0i1",
                blobCid: "bu7v8w9x0y1z2a3b4c5d6e7f8g9h0i1j2",
                sha256: "cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66aa11bb22",
                name: "Foto da quadra.jpg",
                mime: "image/jpeg",
                size: 1_204_331,
                zona: .praca,
                folder: nil,
                deletedAt: nil,
                createdAt: "2026-06-21T21:12:00Z",
                updatedAt: "2026-06-21T21:12:00Z"
            ),
            File(
                rkey: "3m8e2xz0s5d9v",
                cid: "bv8w9x0y1z2a3b4c5d6e7f8g9h0i1j2k3",
                blobCid: "bw9x0y1z2a3b4c5d6e7f8g9h0i1j2k3l4",
                sha256: "dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66aa11bb22cc33",
                name: "Cartaz da festa.jpg",
                mime: "image/jpeg",
                size: 934_221,
                zona: .praca,
                folder: festa,
                deletedAt: nil,
                createdAt: "2026-06-21T20:30:00Z",
                updatedAt: "2026-06-21T20:30:00Z"
            ),
        ]

        bytes = [
            "3m2a8twqpv5z2": Data("%PDF-1.4\narquivo de teste do Tainá\n".utf8),
            "3m5c9vxyq2b7t": Data("%PDF-1.4\narquivo de teste do Tainá\n".utf8),
            "3m7d1wyzr4c8u": Self.tinyPNG,
            "3m8e2xz0s5d9v": Self.tinyPNG,
        ]
        session = nil
    }

    public func instance() async -> TainaResult<Instance> {
        await pause()
        return .success(Instance(bootstrapped: true, tekoa: tekoa, version: "0.6.0"))
    }

    /// Accepts any non-empty username except the literal `sem-acesso`, which
    /// answers 401 `invalid_credentials`, so the error path is previewable.
    public func createSession(username: String, password: String, deviceName: String) async -> TainaResult<Session> {
        await pause()
        guard !username.isEmpty else {
            return .failure(.api(APIError(
                code: "validation_failed",
                status: 422,
                message: "Informe seu nome de usuário.",
                details: ["username": ["não pode ficar em branco"]]
            )))
        }
        guard username != "sem-acesso" else {
            return .failure(.api(APIError(
                code: "invalid_credentials",
                status: 401,
                message: "Usuário ou senha incorretos.",
                details: [:]
            )))
        }

        let now = clock()
        let ava = Ava(
            publicId: "avap2xw5m8q3",
            username: username,
            displayName: nil,
            papel: .morador,
            activatedAt: now,
            deactivatedAt: nil,
            createdAt: now
        )
        let device = DeviceToken(
            publicId: "devp2xw5m8q3",
            name: deviceName.isEmpty ? "Dispositivo" : deviceName,
            lastUsedAt: now,
            revokedAt: nil,
            createdAt: now
        )
        let created = Session(token: "tnd_" + Self.randomHex(32), device: device, me: ava, tekoa: tekoa)
        session = created
        return .success(created)
    }

    public func revokeSession() async -> TainaResult<Void> {
        await pause()
        guard session != nil else {
            return .failure(.api(Self.unauthorized))
        }
        session = nil
        return .success(())
    }

    public func me() async -> TainaResult<Me> {
        await pause()
        guard let current = session else {
            return .failure(.api(Self.unauthorized))
        }
        return .success(Me(ava: current.me, tekoa: current.tekoa, device: current.device))
    }

    public func listFolders() async -> TainaResult<[Folder]> {
        await pause()
        return .success(folders)
    }

    /// Folders are born in the casa; publishing to the praca is a separate
    /// act, so the fake never creates a praca folder here.
    public func createFolder(name: String, parentRkey: String?) async -> TainaResult<Folder> {
        await pause()
        guard !name.isEmpty else {
            return .failure(.api(APIError(
                code: "validation_failed",
                status: 422,
                message: "Informe o nome da pasta.",
                details: ["name": ["não pode ficar em branco"]]
            )))
        }
        let now = clock()
        let folder = Folder(
            rkey: nextRkey(),
            cid: nextCid(),
            name: name,
            zona: .casa,
            folder: parentRkey,
            deletedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        folders.append(folder)
        return .success(folder)
    }

    public func folderContents(folderRkey: String?, limit: Int?, cursor: String?, sort: Sort?) async -> TainaResult<FolderContents> {
        await pause()
        let inside = folders.filter { $0.folder == folderRkey }
        let items = files.filter { $0.folder == folderRkey }
        return .success(FolderContents(folders: inside, items: items, nextCursor: nil))
    }

    public func upload(fileAt fileURL: URL, name: String, mime: String, folderRkey: String?) async -> TainaResult<File> {
        await pause()
        var zona = Zona.casa
        if let folderRkey {
            guard let folder = folders.first(where: { $0.rkey == folderRkey }) else {
                return .failure(.api(APIError(
                    code: "not_found",
                    status: 404,
                    message: "Não encontramos esta pasta.",
                    details: [:]
                )))
            }
            zona = folder.zona
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.size] as? Int64 ?? 0
        let now = clock()
        let file = File(
            rkey: nextRkey(),
            cid: nextCid(),
            blobCid: nextCid(),
            sha256: nextSha256(),
            name: name,
            mime: mime,
            size: size,
            zona: zona,
            folder: folderRkey,
            deletedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        files.append(file)
        bytes[file.rkey] = (try? Data(contentsOf: fileURL)) ?? Data()
        return .success(file)
    }

    public func download(rkey: String) async -> TainaResult<URL> {
        await pause()
        guard let file = files.first(where: { $0.rkey == rkey }) else {
            return .failure(.api(APIError(
                code: "not_found",
                status: 404,
                message: "Não encontramos este arquivo.",
                details: [:]
            )))
        }
        let target = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString + "-" + file.name)
        do {
            try (bytes[file.rkey] ?? Data()).write(to: target, options: .atomic)
            return .success(target)
        } catch {
            return .failure(.network("could not write the downloaded file: \(error.localizedDescription)"))
        }
    }

    /// A tiny PNG for the images the fake knows, and a 404 for everything
    /// else, so the missing-thumbnail path is exercised in previews.
    public func thumbnail(rkey: String, size: ThumbnailSize) async -> TainaResult<Data> {
        await pause()
        guard let file = files.first(where: { $0.rkey == rkey }),
              file.mime.hasPrefix("image/"),
              let payload = bytes[file.rkey] else {
            return .failure(.api(APIError(
                code: "not_found",
                status: 404,
                message: "Este arquivo não tem miniatura.",
                details: [:]
            )))
        }
        return .success(payload)
    }

    // MARK: internals

    private static let unauthorized = APIError(
        code: "not_authenticated",
        status: 401,
        message: "Entre na sua conta para continuar.",
        details: [:]
    )

    private static let tinyPNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
    ) ?? Data()

    private func pause() async {
        try? await Task.sleep(for: delay)
    }

    /// The wire clock: ISO 8601 with a UTC offset, like the server sends.
    private func clock() -> String {
        Date.now.formatted(.iso8601)
    }

    private func nextRkey() -> String {
        counter += 1
        let digits = Array("234567abcdefghijklmnopqrstuvwxyz")
        var value = counter
        var chars: [Character] = []
        while chars.count < 13 {
            chars.append(digits[value % 32])
            value /= 32
        }
        return String(chars)
    }

    private func nextCid() -> String {
        "b" + Self.randomHex(32)
    }

    private func nextSha256() -> String {
        Self.randomHex(64)
    }

    private static func randomHex(_ count: Int) -> String {
        let digits = Array("0123456789abcdef")
        return String((0..<count).map { _ in digits[Int.random(in: 0..<16)] })
    }
}
