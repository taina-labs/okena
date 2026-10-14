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
