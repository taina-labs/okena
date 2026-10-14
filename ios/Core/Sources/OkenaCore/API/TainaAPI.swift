import Foundation

/// Thumbnail size. `sm` for list rows, `md` for the detail view.
public enum ThumbnailSize: String, Sendable, CaseIterable {
    case sm, md
}

/// The API the app talks to. The whole app depends on this and never on
/// `LiveTainaAPI`; previews and tests use `FakeTainaAPI`. One box serves one
/// community, so no method carries an instance parameter.
public protocol TainaAPI: Sendable {
    func instance() async -> TainaResult<Instance>

    func createSession(username: String, password: String, deviceName: String) async -> TainaResult<Session>
    func revokeSession() async -> TainaResult<Void>
    func me() async -> TainaResult<Me>

    func listFolders() async -> TainaResult<[Folder]>
    func createFolder(name: String, parentRkey: String?) async -> TainaResult<Folder>
    func folderContents(folderRkey: String?, limit: Int?, cursor: String?, sort: Sort?) async -> TainaResult<FolderContents>

    func upload(fileAt url: URL, name: String, mime: String, folderRkey: String?) async -> TainaResult<File>
    func download(rkey: String) async -> TainaResult<URL>
    func thumbnail(rkey: String, size: ThumbnailSize) async -> TainaResult<Data>
}
