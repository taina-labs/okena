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
    func inviteStatus(token: String) async -> TainaResult<TokenStatus>
    func acceptInvite(token: String, username: String, password: String, displayName: String?, deviceName: String) async -> TainaResult<Session>
    func resetStatus(token: String) async -> TainaResult<TokenStatus>
    func resetPassword(token: String, password: String, deviceName: String) async -> TainaResult<Session>
    func revokeSession() async -> TainaResult<Void>
    func me() async -> TainaResult<Me>
    func devices() async -> TainaResult<[DeviceToken]>
    func revokeDevice(id: String) async -> TainaResult<Void>

    func listFolders() async -> TainaResult<[Folder]>
    func folder(rkey: String) async -> TainaResult<Folder>
    func createFolder(name: String, parentRkey: String?) async -> TainaResult<Folder>
    func updateFolder(rkey: String, name: String?, zona: Zona?) async -> TainaResult<Folder>
    func moveFolder(rkey: String, parentRkey: String?) async -> TainaResult<Folder>
    func deleteFolder(rkey: String) async -> TainaResult<Void>
    func folderContents(folderRkey: String?, limit: Int?, cursor: String?, sort: Sort?) async -> TainaResult<FolderContents>

    func upload(fileAt url: URL, name: String, mime: String, folderRkey: String?) async -> TainaResult<File>
    func file(rkey: String) async -> TainaResult<File>
    func updateFile(rkey: String, name: String?, zona: Zona?) async -> TainaResult<File>
    func moveFile(rkey: String, folderRkey: String?) async -> TainaResult<File>
    func deleteFile(rkey: String) async -> TainaResult<Void>
    func recent(limit: Int?) async -> TainaResult<Page<File>>
    func download(rkey: String) async -> TainaResult<URL>
    func thumbnail(rkey: String, size: ThumbnailSize) async -> TainaResult<Data>

    func trash(limit: Int?, cursor: String?) async -> TainaResult<Page<File>>
    func restoreFile(rkey: String) async -> TainaResult<File>
    func photos(limit: Int?, cursor: String?) async -> TainaResult<Page<File>>
    func photoTimeline(limit: Int?, cursor: String?) async -> TainaResult<Page<TimelineGroup>>

    func accessTarget(fileRkey: String) async -> TainaResult<AccessTarget>
    func requestAccess(fileRkey: String, motivo: String?) async -> TainaResult<Pedido>
    func accessRequests() async -> TainaResult<Page<Pedido>>
    func myRequests() async -> TainaResult<Page<Pedido>>
    func approveRequest(id: String) async -> TainaResult<Concessao>
    func denyRequest(id: String) async -> TainaResult<Pedido>

    func mural(limit: Int?, cursor: String?) async -> TainaResult<Page<MuralEntry>>
    func storage() async -> TainaResult<StorageStats>
    func saude() async -> TainaResult<Saude>

    func members() async -> TainaResult<Page<Ava>>
}
