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

    /// The backup manifest: every readable file's hash, oldest first, so a
    /// client holding hashes can tell what is missing without a listing.
    func manifest(after: String?, limit: Int?) async -> TainaResult<Page<File>>

    /// One act over many files. The batch answers 200 even on partial
    /// failure; the outcome list carries what each item became.
    func batch(op: BatchOp, ids: [String], folderRkey: String?) async -> TainaResult<[BatchOutcome]>

    func accessTarget(fileRkey: String) async -> TainaResult<AccessTarget>
    func requestAccess(fileRkey: String, motivo: String?) async -> TainaResult<Pedido>
    func accessRequests() async -> TainaResult<Page<Pedido>>
    func myRequests() async -> TainaResult<Page<Pedido>>
    func approveRequest(id: String) async -> TainaResult<Concessao>
    func denyRequest(id: String) async -> TainaResult<Pedido>

    /// The caller's grants, given (`owner`) or received (`reader`), the
    /// revoked ones included: granting must stay visible to be reversible.
    func grants(role: GrantRole) async -> TainaResult<Page<Concessao>>
    func revokeGrant(id: String) async -> TainaResult<Void>

    /// The zeladora's acts over the people: mint an invite, change a
    /// role, switch an account off and on, take an invite back, and hand
    /// out a password link.
    func inviteMember(papel: Papel) async -> TainaResult<MemberInvite>
    func updateMember(id: String, papel: Papel) async -> TainaResult<Ava>
    func deactivateMember(id: String) async -> TainaResult<Void>
    func reactivateMember(id: String) async -> TainaResult<Ava>
    func revokeInvite(id: String) async -> TainaResult<Void>
    func memberResetLink(id: String) async -> TainaResult<ResetLink>

    /// The zeladora sets the community's quota, in bytes.
    func setQuota(bytes: Int64) async -> TainaResult<Tekoa>

    /// The zeladora asks the box to back itself up now.
    func triggerBackup() async -> TainaResult<Void>

    /// Changes the caller's own password while signed in. The box keeps
    /// the calling device signed in and revokes every other one.
    func updatePassword(current: String, new: String) async -> TainaResult<Void>

    func mural(limit: Int?, cursor: String?) async -> TainaResult<Page<MuralEntry>>
    func storage() async -> TainaResult<StorageStats>
    func saude() async -> TainaResult<Saude>

    func members() async -> TainaResult<Page<Ava>>
}
