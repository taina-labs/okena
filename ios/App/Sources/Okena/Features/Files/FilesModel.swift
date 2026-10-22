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
    private(set) var nextCursor: String?
    private(set) var loadingMore = false
    private(set) var moreError = false
    /// The file a row's publish action is running on, so only that row
    /// spins.
    private(set) var publishingRkey: String?
    /// The files this model uploaded, so the rows still in the casa carry
    /// the one-tap publish to the praca.
    private(set) var uploadedRkeys: Set<String> = []

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

    /// The next page of files, walking the cursor the last answer
    /// carried. A page that fails leaves the list and the cursor as they
    /// are, so the sentinel offers the retry.
    func loadMore() async {
        guard !loading, !loadingMore, let cursor = nextCursor else { return }
        loadingMore = true
        let result = await api.folderContents(folderRkey: folderRkey, limit: nil, cursor: cursor, sort: nil)
        await applyMore(result)
        loadingMore = false
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
            uploadedRkeys.insert(file.rkey)
            return .success(())
        case .failure(let failure):
            return .failure(failure)
        }
    }

    /// The completed row's one tap to the praca: the consent the upload
    /// screen owes, at the moment of the intention. The success swaps the
    /// row in place and ends the reminder.
    func publish(_ file: File) async -> TainaResult<Void> {
        publishingRkey = file.rkey
        defer { publishingRkey = nil }
        let result = await api.updateFile(rkey: file.rkey, name: nil, zona: .praca)
        switch await session.screen(result) {
        case .success(let updated):
            entries = Self.replacing(file: updated, in: entries)
            uploadedRkeys.remove(file.rkey)
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

    /// The next page joins the files; the folders do not paginate, so a
    /// later page carries none to add.
    static func appending(_ page: FolderContents, to entries: Entries) -> Entries {
        var next = entries
        next.files.append(contentsOf: page.items)
        return next
    }

    /// Puts the updated file where the old one was, order kept.
    static func replacing(file: File, in entries: Entries) -> Entries {
        var next = entries
        if let index = entries.files.firstIndex(where: { $0.rkey == file.rkey }) {
            next.files[index] = file
        }
        return next
    }

    static func isEmpty(_ entries: Entries) -> Bool {
        entries.folders.isEmpty && entries.files.isEmpty
    }

    /// The uploaded files still in the casa carry the publish action:
    /// the reversal the flow almost hid. A file already in the praca, or
    /// uploaded in an earlier visit, shows nothing extra.
    func showsPublishAction(_ file: File) -> Bool {
        file.zona == .casa && uploadedRkeys.contains(file.rkey)
    }

    /// The destinations a move may offer: never the source itself, and,
    /// when the source is a folder, none of its descendants, where the
    /// move would close a cycle the box refuses. Pure over the readable
    /// list, walking each candidate's chain of parents. What the record
    /// cannot say is ownership: the wire carries no owner, so folders of
    /// other people still show and the box has the last word (the web
    /// filters to the person's own folders; the app cannot see the owner).
    static func moveDestinations(from sourceRkey: String, isFolder: Bool, among folders: [Folder]) -> [Folder] {
        let others = folders.filter { $0.rkey != sourceRkey }
        guard isFolder else {
            return others
        }
        let byRkey = Dictionary(uniqueKeysWithValues: folders.map { ($0.rkey, $0) })
        return others.filter { !isDescendant(of: sourceRkey, walkingUpFrom: $0, byRkey: byRkey) }
    }

    /// True when the chain of parents of `folder` passes through the
    /// ancestor's rkey. The walk caps at the list's size, the same depth
    /// cap the box's own chain query uses: the graph is acyclic, and a
    /// corrupted answer cannot hang the sheet.
    private static func isDescendant(of ancestorRkey: String, walkingUpFrom folder: Folder, byRkey: [String: Folder]) -> Bool {
        var parent = folder.folder
        var steps = 0
        while let rkey = parent, steps <= byRkey.count {
            if rkey == ancestorRkey {
                return true
            }
            parent = byRkey[rkey]?.folder
            steps += 1
        }
        return false
    }

    /// The sentence an upload failure shows: quota has its own, and it
    /// does not promise what the box does not do: what is deleted still
    /// occupies space in the trash for up to 30 days, so "apague algo"
    /// would be a lie.
    static func uploadMessage(for failure: TainaError) -> String {
        if case .api(let error) = failure, error.isQuotaExceeded {
            return "O espaço da comunidade encheu. O que foi apagado segue ocupando espaço na lixeira por até 30 dias; se precisa de espaço agora, fale com quem cuida da comunidade."
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

    /// Where an upload on this screen lands: the folder's zona, casa at
    /// the root. The destination is never silent, and in the casa the
    /// sentence names the way back to the praca.
    static func uploadDestinationMessage(for zona: Zona) -> String {
        zona == .casa
            ? "Vai para a sua casa: só você vê, até publicar na praça."
            : "Vai para a praça: todos os moradores vão ver."
    }

    /// The kind a person reads for the raw mime, the web's `file_kind/1`.
    static func fileKind(_ mime: String) -> String {
        if mime.hasPrefix("image/") { return "Imagem" }
        if mime.hasPrefix("video/") { return "Vídeo" }
        if mime.hasPrefix("audio/") { return "Áudio" }
        if mime == "application/pdf" { return "PDF" }
        if mime == "application/zip" { return "ZIP" }
        if mime.hasPrefix("text/") { return "Texto" }
        return "Arquivo"
    }

    /// The hash under its real name, the web's details modal: the label
    /// says what it is for, the raw value stays selectable underneath.
    static let hashLabel = "Assinatura do arquivo"

    static let hashNote = "É como o Tainá confere que o arquivo está intacto."

    /// "N arquivos" while a page is still missing, "N arquivos
    /// carregados" at the end of the list. The folders do not paginate,
    /// so the count talks about files.
    static func countLabel(count: Int, hasMore: Bool) -> String {
        let noun = count == 1 ? "1 arquivo" : "\(count) arquivos"
        guard hasMore else { return noun }
        return noun + (count == 1 ? " carregado" : " carregados")
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
            nextCursor = contents.nextCursor
            moreError = false
            error = nil
        case .failure(let failure):
            error = failure
        }
    }

    private func applyMore(_ result: TainaResult<FolderContents>) async {
        switch await session.screen(result) {
        case .success(let contents):
            entries = Self.appending(contents, to: entries)
            nextCursor = contents.nextCursor
            moreError = false
        case .failure:
            // A page that fails leaves the list as it is and the cursor
            // alive: the sentinel offers the retry.
            moreError = true
        }
    }
}
