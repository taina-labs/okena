import OkenaCore
import SwiftUI
import UniformTypeIdentifiers

/// The browser's state, for the root and for any folder alike. The loading
/// logic lives here once; the transitions are pure functions the views
/// never reimplement.
@MainActor
@Observable
final class FilesModel {
    struct Entries: Equatable {
        var folders: [Folder] = []
        var files: [File] = []
    }

    private(set) var entries = Entries()
    private(set) var loading = false
    private(set) var uploading = false
    private(set) var error: TainaError?

    let folderRkey: String?

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel, folderRkey: String?) {
        self.api = api
        self.session = session
        self.folderRkey = folderRkey
    }

    func load() async {
        loading = true
        let result = await api.folderContents(folderRkey: folderRkey, limit: nil, cursor: nil, sort: nil)
        await apply(result)
        loading = false
    }

    /// Creates the folder and puts it at the end of the list, where the
    /// server's own order would put it on the next refresh.
    func createFolder(named name: String) async -> TainaResult<Void> {
        let result = await api.createFolder(name: name, parentRkey: folderRkey)
        switch await session.screen(result) {
        case .success(let folder):
            entries = Self.inserting(folder: folder, into: entries)
            return .success(())
        case .failure(let failure):
            return .failure(failure)
        }
    }

    func upload(from url: URL) async -> TainaResult<Void> {
        uploading = true
        defer { uploading = false }
        // A picked URL is security scoped: the read holds only while the
        // access is held.
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let result = await api.upload(
            fileAt: url,
            name: url.lastPathComponent,
            mime: Self.mime(for: url),
            folderRkey: folderRkey
        )
        switch await session.screen(result) {
        case .success(let file):
            entries = Self.inserting(file: file, into: entries)
            return .success(())
        case .failure(let failure):
            return .failure(failure)
        }
    }

    // MARK: folder acts

    /// The acts on the folder itself, not on its contents: the caller owns
    /// what the screen shows of the folder afterwards. The results are
    /// screened like every other call, so a 401 leaves on its own.

    func renameFolder(_ folder: Folder, to name: String) async -> TainaResult<Folder> {
        let result = await api.updateFolder(rkey: folder.rkey, name: name, zona: nil)
        return await session.screen(result)
    }

    /// Moves the folder under another one, nil for the root.
    func moveFolder(_ folder: Folder, to parent: Folder?) async -> TainaResult<Folder> {
        let result = await api.moveFolder(rkey: folder.rkey, parentRkey: parent?.rkey)
        return await session.screen(result)
    }

    /// The same updateFolder the rename uses, with the zona instead of the
    /// name: publishing to the praca and coming back are one field.
    func setFolderZone(_ folder: Folder, to zona: Zona) async -> TainaResult<Folder> {
        let result = await api.updateFolder(rkey: folder.rkey, name: nil, zona: zona)
        return await session.screen(result)
    }

    func deleteFolder(_ folder: Folder) async -> TainaResult<Void> {
        let result = await api.deleteFolder(rkey: folder.rkey)
        return await session.screen(result)
    }

    // MARK: pure transitions

    static func entries(from contents: FolderContents) -> Entries {
        Entries(folders: contents.folders, files: contents.items)
    }

    static func inserting(folder: Folder, into entries: Entries) -> Entries {
        var next = entries
        next.folders.append(folder)
        return next
    }

    static func inserting(file: File, into entries: Entries) -> Entries {
        var next = entries
        next.files.append(file)
        return next
    }

    static func isEmpty(_ entries: Entries) -> Bool {
        entries.folders.isEmpty && entries.files.isEmpty
    }

    /// The sentence an upload failure shows: quota has its own, the rest is
    /// the error's own pt-BR description.
    static func uploadMessage(for failure: TainaError) -> String {
        if case .api(let error) = failure, error.isQuotaExceeded {
            return "O espaço da comunidade encheu. Apague algo para caber mais."
        }
        return failure.errorDescription ?? "Não deu para enviar o arquivo."
    }

    // MARK: pure copy

    /// The words of the zona change and of the trash, shared by the file
    /// and the folder screens. The action always offers the opposite of
    /// where the item is: the guarded zona below is the CURRENT one.

    static func zonaActionLabel(for zona: Zona) -> String {
        zona == .casa ? "Publicar na praça" : "Tirar da praça"
    }

    static func zonaConfirmTitle(name: String, zona: Zona) -> String {
        zona == .casa ? "Publicar \"\(name)\" na praça?" : "Tirar \"\(name)\" da praça?"
    }

    static func zonaConfirmBody(for zona: Zona) -> String {
        zona == .casa
            ? "Todos os moradores vão poder ver. Você pode tirar da praça quando quiser."
            : "Volta a ser só seu. Só você, e quem você deixar, vê de novo."
    }

    /// The folder confirm says what the file confirm does not: only the
    /// folder goes to the praça, the files inside stay as they are.
    static func zonaFolderBody(name: String, zona: Zona) -> String {
        guard zona == .casa else { return zonaConfirmBody(for: zona) }
        return zonaConfirmBody(for: zona) + " Só a pasta entra na praça. Os arquivos dentro dela continuam como estão."
    }

    static func zonaConfirmPrimary(for zona: Zona) -> String {
        zona == .casa ? "Publicar" : "Tirar da praça"
    }

    static func deleteFileTitle(name: String) -> String {
        "Excluir \"\(name)\"?"
    }

    static let deleteFileMessage = "Vai para a lixeira. Dá para restaurar em até 30 dias."

    static func deleteFolderTitle(name: String) -> String {
        "Excluir a pasta \"\(name)\"?"
    }

    /// The folder goes to the trash with everything inside, but only the
    /// files come back, one by one: the copy does not promise what the
    /// system does not do.
    static let deleteFolderMessage = "A pasta e o que tem dentro vão para a lixeira. Os arquivos voltam um a um; a pasta em si, não."

    /// The default motivo of a pedido made from the file screen, the same
    /// sentence the web sends.
    static let accessMotivo = "Pedido de acesso pela tela do arquivo"

    /// The mime from the file's extension, octet-stream when unknown.
    static func mime(for url: URL) -> String {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return "application/octet-stream"
        }
        return type.preferredMIMEType ?? "application/octet-stream"
    }

    // MARK: internals

    private func apply(_ result: TainaResult<FolderContents>) async {
        switch await session.screen(result) {
        case .success(let contents):
            entries = Self.entries(from: contents)
            error = nil
        case .failure(let failure):
            error = failure
        }
    }
}
