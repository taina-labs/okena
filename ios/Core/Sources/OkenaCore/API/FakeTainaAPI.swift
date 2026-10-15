import Foundation

/// A `TainaAPI` over an in-memory world: the preview double and the UI test
/// double, and the reason a screen can be built and looked at without a box.
/// It never touches `Transport`, `HostStore` or `SessionStore`.
public actor FakeTainaAPI: TainaAPI {
    private let delay: Duration = .milliseconds(300)
    private var counter = 0

    private var tekoa: Tekoa
    private var avas: [Ava]
    private var neighbor: Ava
    private var devices: [DeviceToken]
    private var folders: [Folder]
    private var files: [File]
    private var receivedPedidos: [Pedido]
    private var sentPedidos: [Pedido]
    private var muralEntries: [MuralEntry]
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

        let ana = Ava(
            publicId: "avap2xw5m8q3",
            username: "ana",
            displayName: "Ana Souza",
            papel: .zelador,
            activatedAt: "2026-02-01T09:00:00Z",
            deactivatedAt: nil,
            createdAt: "2026-02-01T09:00:00Z"
        )
        let joana = Ava(
            publicId: "avaq7r2m5xk9p1",
            username: "joana",
            displayName: "Joana Reis",
            papel: .morador,
            activatedAt: "2026-02-02T09:00:00Z",
            deactivatedAt: nil,
            createdAt: "2026-02-02T09:00:00Z"
        )
        let rafael = Ava(
            publicId: "avam4t8y2w6q0s3",
            username: "rafael",
            displayName: "Rafael Nunes",
            papel: .morador,
            activatedAt: "2026-02-03T09:00:00Z",
            deactivatedAt: nil,
            createdAt: "2026-02-03T09:00:00Z"
        )
        avas = [ana, joana, rafael]
        // The seeded neighbor the pedido screens ask about: in the fake
        // every listed file is the person's own, so the access flow
        // pretends she owns each one.
        neighbor = joana

        devices = [
            DeviceToken(
                publicId: "devc9x2m5kq8",
                name: "iPad da Ana",
                lastUsedAt: "2026-09-30T18:20:00Z",
                revokedAt: "2026-10-01T08:00:00Z",
                createdAt: "2026-05-12T11:00:00Z"
            ),
        ]

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
            File(
                rkey: "3m9f4xk1q7v2n",
                cid: "bx0y1z2a3b4c5d6e7f8g9h0i1j2k3l4m5",
                blobCid: "by1z2a3b4c5d6e7f8g9h0i1j2k3l4m5n6",
                sha256: "ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66aa11bb22cc33dd44",
                name: "Apresentacao na escola.mp4",
                mime: "video/mp4",
                size: 52_428_800,
                zona: .praca,
                folder: festa,
                deletedAt: nil,
                createdAt: "2026-06-21T22:05:00Z",
                updatedAt: "2026-06-21T22:05:00Z"
            ),
        ]

        bytes = [
            "3m2a8twqpv5z2": Data("%PDF-1.4\narquivo de teste do Tainá\n".utf8),
            "3m5c9vxyq2b7t": Data("%PDF-1.4\narquivo de teste do Tainá\n".utf8),
            "3m7d1wyzr4c8u": Self.tinyPNG,
            "3m8e2xz0s5d9v": Self.tinyPNG,
            "3m9f4xk1q7v2n": Data("vídeo de teste do Tainá".utf8),
        ]

        receivedPedidos = [
            Pedido(
                publicId: "ped3xk9mq2v7w4",
                tipo: "leitura",
                recurso: "3m2a8twqpv5z2",
                motivo: "Preciso do estatuto para a reuniao de domingo.",
                status: .pendente,
                decididoEm: nil,
                createdAt: "2026-10-12T10:00:00Z",
                pedinte: joana,
                dono: ana
            ),
        ]
        sentPedidos = [
            Pedido(
                publicId: "ped7qm2xk4v9n1",
                tipo: "leitura",
                recurso: "3q9p2xk5m8v1",
                motivo: "A foto do crachá para o mural da quadra.",
                status: .pendente,
                decididoEm: nil,
                createdAt: "2026-10-13T15:30:00Z",
                pedinte: ana,
                dono: rafael
            ),
            Pedido(
                publicId: "ped9v2xk7m4q1n",
                tipo: "leitura",
                recurso: "3r2v5xk9m8q1",
                motivo: nil,
                status: .aprovado,
                decididoEm: "2026-10-11T09:00:00Z",
                createdAt: "2026-10-10T09:00:00Z",
                pedinte: ana,
                dono: joana
            ),
        ]

        muralEntries = [
            MuralEntry(
                seq: 4,
                tipo: "arquivo.publicado",
                payload: [
                    "name": .string("Foto da quadra.jpg"),
                    "zona": .string("praca"),
                    "size": .int(1_204_331),
                ],
                cid: "bz8x6k4m2q9v1p3r5t7w2y4a6c8e0g2",
                prev: "by7w5j3l1p8u0o2q4s6v1x3z5a7d9f1",
                createdAt: "2026-06-21T21:12:00Z"
            ),
            MuralEntry(
                seq: 3,
                tipo: "pedido.aprovado",
                payload: [
                    "file": .string("Lista de presenca.pdf"),
                    "reader": .string("rafael"),
                    "motivo": .null,
                ],
                cid: "by7w5j3l1p8u0o2q4s6v1x3z5a7d9f1",
                prev: "bx6v4i2k0p7t9n1p3r5u0w2y4z6c8e0g2",
                createdAt: "2026-06-21T20:45:00Z"
            ),
            MuralEntry(
                seq: 2,
                tipo: "arquivo.criado",
                payload: [
                    "name": .string("Estatuto da associacao.pdf"),
                    "zona": .string("casa"),
                    "tags": .array([.string("assembleia"), .string("estatuto")]),
                ],
                cid: "bx6v4i2k0p7t9n1p3r5u0w2y4z6c8e0g2",
                prev: "bw5u3h1j9o6s8m0o2q4t9v1x3y5a7d9f1",
                createdAt: "2026-03-11T09:30:00Z"
            ),
            MuralEntry(
                seq: 1,
                tipo: "pasta.criada",
                payload: [
                    "name": .string("Documentos da assembleia"),
                    "zona": .string("casa"),
                ],
                cid: "bw5u3h1j9o6s8m0o2q4t9v1x3y5a7d9f1",
                prev: nil,
                createdAt: "2026-03-10T14:00:00Z"
            ),
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
        devices.insert(device, at: 0)
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

    /// The person's own devices, most recent first.
    public func devices() async -> TainaResult<[DeviceToken]> {
        await pause()
        return .success(devices)
    }

    /// Revoking is idempotent: a device already revoked stays as is.
    public func revokeDevice(id: String) async -> TainaResult<Void> {
        await pause()
        guard let index = devices.firstIndex(where: { $0.publicId == id }) else {
            return .failure(.api(APIError(
                code: "not_found",
                status: 404,
                message: "Não encontramos este aparelho.",
                details: [:]
            )))
        }
        if devices[index].revokedAt == nil {
            let device = devices[index]
            devices[index] = DeviceToken(
                publicId: device.publicId,
                name: device.name,
                lastUsedAt: device.lastUsedAt,
                revokedAt: clock(),
                createdAt: device.createdAt
            )
        }
        return .success(())
    }

    public func listFolders() async -> TainaResult<[Folder]> {
        await pause()
        return .success(folders.filter { $0.deletedAt == nil })
    }

    public func folder(rkey: String) async -> TainaResult<Folder> {
        await pause()
        guard let folder = folders.first(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFolder))
        }
        return .success(folder)
    }

    /// Renames, publishes to the praca or brings back to the casa; each act
    /// is its own call, like on the box.
    public func updateFolder(rkey: String, name: String?, zona: Zona?) async -> TainaResult<Folder> {
        await pause()
        guard let index = folders.firstIndex(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFolder))
        }
        let current = folders[index]
        let updated = Folder(
            rkey: current.rkey,
            cid: current.cid,
            name: name ?? current.name,
            zona: zona ?? current.zona,
            folder: current.folder,
            deletedAt: current.deletedAt,
            createdAt: current.createdAt,
            updatedAt: clock()
        )
        folders[index] = updated
        return .success(updated)
    }

    public func moveFolder(rkey: String, parentRkey: String?) async -> TainaResult<Folder> {
        await pause()
        guard let index = folders.firstIndex(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFolder))
        }
        if let parentRkey, !folders.contains(where: { $0.rkey == parentRkey }) {
            return .failure(.api(Self.notFoundFolder))
        }
        guard !Self.cycles(rkey: rkey, into: parentRkey, folders: folders) else {
            return .failure(.api(APIError(
                code: "cycle",
                status: 409,
                message: "A pasta não pode ficar dentro dela mesma.",
                details: [:]
            )))
        }
        let current = folders[index]
        let moved = Folder(
            rkey: current.rkey,
            cid: current.cid,
            name: current.name,
            zona: current.zona,
            folder: parentRkey,
            deletedAt: current.deletedAt,
            createdAt: current.createdAt,
            updatedAt: clock()
        )
        folders[index] = moved
        return .success(moved)
    }

    /// Soft deletes the whole subtree: the folder, the folders inside it
    /// and every file they hold.
    public func deleteFolder(rkey: String) async -> TainaResult<Void> {
        await pause()
        guard folders.contains(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFolder))
        }
        let subtree = Self.subtreeRkeys(of: rkey, in: folders)
        let now = clock()
        folders = folders.map { folder in
            guard subtree.contains(folder.rkey) else { return folder }
            return Folder(
                rkey: folder.rkey,
                cid: folder.cid,
                name: folder.name,
                zona: folder.zona,
                folder: folder.folder,
                deletedAt: now,
                createdAt: folder.createdAt,
                updatedAt: now
            )
        }
        files = files.map { file in
            guard let parent = file.folder, subtree.contains(parent) else { return file }
            return Self.stamping(file, deletedAt: now, updatedAt: now)
        }
        return .success(())
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
        let inside = folders.filter { $0.folder == folderRkey && $0.deletedAt == nil }
        let items = files.filter { $0.folder == folderRkey && $0.deletedAt == nil }
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

    public func file(rkey: String) async -> TainaResult<File> {
        await pause()
        guard let file = files.first(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFile))
        }
        return .success(file)
    }

    public func updateFile(rkey: String, name: String?, zona: Zona?) async -> TainaResult<File> {
        await pause()
        guard let index = files.firstIndex(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFile))
        }
        let current = files[index]
        let updated = File(
            rkey: current.rkey,
            cid: current.cid,
            blobCid: current.blobCid,
            sha256: current.sha256,
            name: name ?? current.name,
            mime: current.mime,
            size: current.size,
            zona: zona ?? current.zona,
            folder: current.folder,
            deletedAt: current.deletedAt,
            createdAt: current.createdAt,
            updatedAt: clock()
        )
        files[index] = updated
        return .success(updated)
    }

    public func moveFile(rkey: String, folderRkey: String?) async -> TainaResult<File> {
        await pause()
        guard let index = files.firstIndex(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFile))
        }
        if let folderRkey, !folders.contains(where: { $0.rkey == folderRkey }) {
            return .failure(.api(Self.notFoundFolder))
        }
        let current = files[index]
        let moved = File(
            rkey: current.rkey,
            cid: current.cid,
            blobCid: current.blobCid,
            sha256: current.sha256,
            name: current.name,
            mime: current.mime,
            size: current.size,
            zona: current.zona,
            folder: folderRkey,
            deletedAt: current.deletedAt,
            createdAt: current.createdAt,
            updatedAt: clock()
        )
        files[index] = moved
        return .success(moved)
    }

    /// The file goes to the trash, from where only its owner restores it.
    public func deleteFile(rkey: String) async -> TainaResult<Void> {
        await pause()
        guard let index = files.firstIndex(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFile))
        }
        let now = clock()
        files[index] = Self.stamping(files[index], deletedAt: now, updatedAt: now)
        return .success(())
    }

    public func recent(limit: Int?) async -> TainaResult<Page<File>> {
        await pause()
        let readable = files
            .filter { $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
        return .success(Page.slice(of: readable, limit: limit, cursor: nil))
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

    public func trash(limit: Int?, cursor: String?) async -> TainaResult<Page<File>> {
        await pause()
        let discarded = files
            .filter { $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? "") > ($1.deletedAt ?? "") }
        return .success(Page.slice(of: discarded, limit: limit, cursor: cursor))
    }

    public func restoreFile(rkey: String) async -> TainaResult<File> {
        await pause()
        guard let index = files.firstIndex(where: { $0.rkey == rkey }) else {
            return .failure(.api(Self.notFoundFile))
        }
        let restored = Self.stamping(files[index], deletedAt: nil, updatedAt: clock())
        files[index] = restored
        return .success(restored)
    }

    public func photos(limit: Int?, cursor: String?) async -> TainaResult<Page<File>> {
        await pause()
        return .success(Page.slice(of: Self.visual(files: files), limit: limit, cursor: cursor))
    }

    public func photoTimeline(limit: Int?, cursor: String?) async -> TainaResult<Page<TimelineGroup>> {
        await pause()
        let days = Self.timelineGroups(from: Self.visual(files: files))
        return .success(Page.slice(of: days, limit: limit, cursor: cursor))
    }

    public func accessTarget(fileRkey: String) async -> TainaResult<AccessTarget> {
        await pause()
        guard let file = files.first(where: { $0.rkey == fileRkey }) else {
            return .failure(.api(Self.notFoundFile))
        }
        return .success(AccessTarget(owner: neighbor, rkey: file.rkey, name: file.name))
    }

    /// The pedido registers the question; it grants nothing.
    public func requestAccess(fileRkey: String, motivo: String?) async -> TainaResult<Pedido> {
        await pause()
        guard let file = files.first(where: { $0.rkey == fileRkey }) else {
            return .failure(.api(Self.notFoundFile))
        }
        let now = clock()
        let pedido = Pedido(
            publicId: "ped" + Self.randomHex(9),
            tipo: "leitura",
            recurso: file.rkey,
            motivo: motivo,
            status: .pendente,
            decididoEm: nil,
            createdAt: now,
            pedinte: session?.me ?? avas[0],
            dono: neighbor
        )
        sentPedidos.insert(pedido, at: 0)
        return .success(pedido)
    }

    public func accessRequests() async -> TainaResult<Page<Pedido>> {
        await pause()
        return .success(Page(items: receivedPedidos, nextCursor: nil))
    }

    public func myRequests() async -> TainaResult<Page<Pedido>> {
        await pause()
        return .success(Page(items: sentPedidos, nextCursor: nil))
    }

    /// Approving grants the read: the concessao is born and the pedido
    /// closes. A pedido decided once cannot be decided again.
    public func approveRequest(id: String) async -> TainaResult<Concessao> {
        await pause()
        let decided = decide(id: id, to: .aprovado)
        switch decided {
        case .success(let pedido):
            return .success(Concessao(
                publicId: "con" + Self.randomHex(9),
                tipo: pedido.tipo,
                recurso: pedido.recurso,
                concedidaEm: pedido.decididoEm,
                revogadaEm: nil,
                createdAt: clock(),
                leitor: pedido.pedinte,
                dono: pedido.dono
            ))
        case .failure(let error):
            return .failure(error)
        }
    }

    public func denyRequest(id: String) async -> TainaResult<Pedido> {
        await pause()
        return decide(id: id, to: .negado)
    }

    public func mural(limit: Int?, cursor: String?) async -> TainaResult<Page<MuralEntry>> {
        await pause()
        return .success(Page.slice(of: muralEntries, limit: limit, cursor: cursor))
    }

    public func storage() async -> TainaResult<StorageStats> {
        await pause()
        return .success(Self.stats(files: files, quotaBytes: tekoa.storageQuotaBytes))
    }

    public func saude() async -> TainaResult<Saude> {
        await pause()
        return .success(Saude(
            storage: Self.stats(files: files, quotaBytes: tekoa.storageQuotaBytes),
            jobs: ["renditions": 0, "backups": 0],
            backup: Saude.Backup(at: "2026-10-14T03:00:00Z", bytes: 1_829_000_000)
        ))
    }

    public func members() async -> TainaResult<Page<Ava>> {
        await pause()
        // The box lists the zeladoras first.
        let ordered = avas.sorted { lhs, rhs in
            if lhs.papel != rhs.papel {
                return lhs.papel == .zelador
            }
            return lhs.label < rhs.label
        }
        return .success(Page(items: ordered, nextCursor: nil))
    }

    // MARK: internals

    private static let unauthorized = APIError(
        code: "not_authenticated",
        status: 401,
        message: "Entre na sua conta para continuar.",
        details: [:]
    )

    private static let notFoundFolder = APIError(
        code: "not_found",
        status: 404,
        message: "Não encontramos esta pasta.",
        details: [:]
    )

    private static let notFoundFile = APIError(
        code: "not_found",
        status: 404,
        message: "Não encontramos este arquivo.",
        details: [:]
    )

    /// Decides a received pedido, once: a second decision is a conflict,
    /// like the box answers. Pure over the received list, so the rule is
    /// provable without the actor.
    private func decide(id: String, to status: PedidoStatus) -> TainaResult<Pedido> {
        guard let index = receivedPedidos.firstIndex(where: { $0.publicId == id }) else {
            return .failure(.api(APIError(
                code: "not_found",
                status: 404,
                message: "Não encontramos este pedido.",
                details: [:]
            )))
        }
        guard receivedPedidos[index].status == .pendente else {
            return .failure(.api(APIError(
                code: "already_decided",
                status: 409,
                message: "Este pedido já foi decidido.",
                details: [:]
            )))
        }
        let pedido = receivedPedidos[index]
        let decided = Pedido(
            publicId: pedido.publicId,
            tipo: pedido.tipo,
            recurso: pedido.recurso,
            motivo: pedido.motivo,
            status: status,
            decididoEm: clock(),
            createdAt: pedido.createdAt,
            pedinte: pedido.pedinte,
            dono: pedido.dono
        )
        receivedPedidos[index] = decided
        return .success(decided)
    }

    /// The record with its trash state and clock restamped. Pure.
    private static func stamping(_ file: File, deletedAt: String?, updatedAt: String) -> File {
        File(
            rkey: file.rkey,
            cid: file.cid,
            blobCid: file.blobCid,
            sha256: file.sha256,
            name: file.name,
            mime: file.mime,
            size: file.size,
            zona: file.zona,
            folder: file.folder,
            deletedAt: deletedAt,
            createdAt: file.createdAt,
            updatedAt: updatedAt
        )
    }

    /// The photos and videos still among the living, newest first. Pure.
    private static func visual(files: [File]) -> [File] {
        files
            .filter { $0.deletedAt == nil && ($0.mime.hasPrefix("image/") || $0.mime.hasPrefix("video/")) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Groups the files into days, newest first: the day is the date prefix
    /// of the wire clock, like the box reads the effective date. Pure.
    static func timelineGroups(from files: [File]) -> [TimelineGroup] {
        var days: [String] = []
        var byDay: [String: [File]] = [:]
        for file in files.sorted(by: { $0.createdAt > $1.createdAt }) {
            let day = String(file.createdAt.prefix(10))
            if byDay[day] == nil {
                days.append(day)
            }
            byDay[day, default: []].append(file)
        }
        return days.map { TimelineGroup(date: $0, photos: byDay[$0] ?? []) }
    }

    /// True when moving `rkey` into `parentRkey` would close a cycle: the
    /// new parent is the folder itself or one of the folders above it.
    /// Pure.
    static func cycles(rkey: String, into parentRkey: String?, folders: [Folder]) -> Bool {
        var current = parentRkey
        while let next = current {
            if next == rkey {
                return true
            }
            current = folders.first(where: { $0.rkey == next })?.folder
        }
        return false
    }

    /// The folder and every folder below it, however deep. Pure.
    static func subtreeRkeys(of rkey: String, in folders: [Folder]) -> Set<String> {
        var subtree: Set<String> = [rkey]
        var growing = true
        while growing {
            growing = false
            for folder in folders where subtree.contains(folder.folder ?? "") && !subtree.contains(folder.rkey) {
                subtree.insert(folder.rkey)
                growing = true
            }
        }
        return subtree
    }

    /// The storage portrait read straight from the records: bytes by kind,
    /// counts, and what the trash holds right now. Pure.
    static func stats(files: [File], quotaBytes: Int64?) -> StorageStats {
        let alive = files.filter { $0.deletedAt == nil }
        let discarded = files.filter { $0.deletedAt != nil }

        var photoBytes: Int64 = 0
        var videoBytes: Int64 = 0
        var documentBytes: Int64 = 0
        var otherBytes: Int64 = 0
        for file in alive {
            if file.mime.hasPrefix("image/") {
                photoBytes += file.size
            } else if file.mime.hasPrefix("video/") {
                videoBytes += file.size
            } else if file.mime.hasPrefix("application/") {
                documentBytes += file.size
            } else {
                otherBytes += file.size
            }
        }

        return StorageStats(
            usedBytes: photoBytes + videoBytes + documentBytes + otherBytes,
            quotaBytes: quotaBytes,
            byKind: StorageStats.ByKind(
                photos: photoBytes,
                videos: videoBytes,
                documents: documentBytes,
                others: otherBytes
            ),
            files: Int64(alive.count),
            photos: Int64(alive.filter { $0.mime.hasPrefix("image/") }.count),
            trash: StorageStats.Trash(
                count: Int64(discarded.count),
                bytes: discarded.reduce(0) { $0 + $1.size }
            )
        )
    }

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
