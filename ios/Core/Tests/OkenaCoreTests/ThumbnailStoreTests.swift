import Foundation
import Testing

@testable import OkenaCore

private struct StubAPI: TainaAPI {
    let thumbnailAnswer: @Sendable (String, ThumbnailSize) async -> TainaResult<Data>

    func instance() async -> TainaResult<Instance> { .failure(.cancelled) }
    func createSession(username: String, password: String, deviceName: String) async -> TainaResult<Session> { .failure(.cancelled) }
    func inviteStatus(token: String) async -> TainaResult<TokenStatus> { .failure(.cancelled) }
    func acceptInvite(token: String, username: String, password: String, displayName: String?, deviceName: String) async -> TainaResult<Session> { .failure(.cancelled) }
    func resetStatus(token: String) async -> TainaResult<TokenStatus> { .failure(.cancelled) }
    func resetPassword(token: String, password: String, deviceName: String) async -> TainaResult<Session> { .failure(.cancelled) }
    func revokeSession() async -> TainaResult<Void> { .failure(.cancelled) }
    func me() async -> TainaResult<Me> { .failure(.cancelled) }
    func devices() async -> TainaResult<[DeviceToken]> { .failure(.cancelled) }
    func revokeDevice(id: String) async -> TainaResult<Void> { .failure(.cancelled) }
    func listFolders() async -> TainaResult<[Folder]> { .failure(.cancelled) }
    func folder(rkey: String) async -> TainaResult<Folder> { .failure(.cancelled) }
    func createFolder(name: String, parentRkey: String?) async -> TainaResult<Folder> { .failure(.cancelled) }
    func updateFolder(rkey: String, name: String?, zona: Zona?) async -> TainaResult<Folder> { .failure(.cancelled) }
    func moveFolder(rkey: String, parentRkey: String?) async -> TainaResult<Folder> { .failure(.cancelled) }
    func deleteFolder(rkey: String) async -> TainaResult<Void> { .failure(.cancelled) }
    func folderContents(folderRkey: String?, limit: Int?, cursor: String?, sort: Sort?) async -> TainaResult<FolderContents> { .failure(.cancelled) }
    func upload(fileAt url: URL, name: String, mime: String, folderRkey: String?) async -> TainaResult<File> { .failure(.cancelled) }
    func file(rkey: String) async -> TainaResult<File> { .failure(.cancelled) }
    func updateFile(rkey: String, name: String?, zona: Zona?) async -> TainaResult<File> { .failure(.cancelled) }
    func moveFile(rkey: String, folderRkey: String?) async -> TainaResult<File> { .failure(.cancelled) }
    func deleteFile(rkey: String) async -> TainaResult<Void> { .failure(.cancelled) }
    func recent(limit: Int?) async -> TainaResult<Page<File>> { .failure(.cancelled) }
    func download(rkey: String) async -> TainaResult<URL> { .failure(.cancelled) }

    func trash(limit: Int?, cursor: String?) async -> TainaResult<Page<File>> { .failure(.cancelled) }
    func restoreFile(rkey: String) async -> TainaResult<File> { .failure(.cancelled) }
    func photos(limit: Int?, cursor: String?) async -> TainaResult<Page<File>> { .failure(.cancelled) }
    func photoTimeline(limit: Int?, cursor: String?) async -> TainaResult<Page<TimelineGroup>> { .failure(.cancelled) }
    func accessTarget(fileRkey: String) async -> TainaResult<AccessTarget> { .failure(.cancelled) }
    func requestAccess(fileRkey: String, motivo: String?) async -> TainaResult<Pedido> { .failure(.cancelled) }
    func accessRequests() async -> TainaResult<Page<Pedido>> { .failure(.cancelled) }
    func myRequests() async -> TainaResult<Page<Pedido>> { .failure(.cancelled) }
    func approveRequest(id: String) async -> TainaResult<Concessao> { .failure(.cancelled) }
    func denyRequest(id: String) async -> TainaResult<Pedido> { .failure(.cancelled) }
    func manifest(after: String?, limit: Int?) async -> TainaResult<Page<File>> { .failure(.cancelled) }
    func batch(op: BatchOp, ids: [String], folderRkey: String?) async -> TainaResult<[BatchOutcome]> { .failure(.cancelled) }
    func grants(role: GrantRole) async -> TainaResult<Page<Concessao>> { .failure(.cancelled) }
    func revokeGrant(id: String) async -> TainaResult<Void> { .failure(.cancelled) }
    func inviteMember(papel: Papel) async -> TainaResult<MemberInvite> { .failure(.cancelled) }
    func updateMember(id: String, papel: Papel) async -> TainaResult<Ava> { .failure(.cancelled) }
    func deactivateMember(id: String) async -> TainaResult<Void> { .failure(.cancelled) }
    func reactivateMember(id: String) async -> TainaResult<Ava> { .failure(.cancelled) }
    func revokeInvite(id: String) async -> TainaResult<Void> { .failure(.cancelled) }
    func memberResetLink(id: String) async -> TainaResult<ResetLink> { .failure(.cancelled) }
    func setQuota(bytes: Int64) async -> TainaResult<Tekoa> { .failure(.cancelled) }
    func triggerBackup() async -> TainaResult<Void> { .failure(.cancelled) }
    func updatePassword(current: String, new: String) async -> TainaResult<Void> { .failure(.cancelled) }
    func mural(limit: Int?, cursor: String?) async -> TainaResult<Page<MuralEntry>> { .failure(.cancelled) }
    func storage() async -> TainaResult<StorageStats> { .failure(.cancelled) }
    func saude() async -> TainaResult<Saude> { .failure(.cancelled) }
    func members() async -> TainaResult<Page<Ava>> { .failure(.cancelled) }

    func thumbnail(rkey: String, size: ThumbnailSize) async -> TainaResult<Data> {
        await thumbnailAnswer(rkey, size)
    }
}

@Test func aMissFetchesOnceAndHitsServeFromCache() async {
    let counter = Counter()
    let store = ThumbnailStore(api: StubAPI { _, _ in
        _ = await counter.next()
        return .success(Data([0x01]))
    })

    #expect(await store.data(rkey: "3m2a8twqpv5z2", size: .sm).value != nil)
    #expect(await counter.value == 1)

    // A second pass over the grid does not fetch again.
    #expect(await store.data(rkey: "3m2a8twqpv5z2", size: .sm).value != nil)
    #expect(await counter.value == 1)

    // The size is part of the key.
    #expect(await store.data(rkey: "3m2a8twqpv5z2", size: .md).value != nil)
    #expect(await counter.value == 2)
}

@Test func aFailureIsNotCached() async {
    let counter = Counter()
    let store = ThumbnailStore(api: StubAPI { _, _ in
        _ = await counter.next()
        return .failure(.api(APIError(code: "not_found", status: 404, message: "Este arquivo não tem miniatura.", details: [:])))
    })

    #expect(await store.data(rkey: "3m2a8twqpv5z2", size: .sm).value == nil)
    #expect(await store.data(rkey: "3m2a8twqpv5z2", size: .sm).value == nil)
    #expect(await counter.value == 2)
}

@Test func clearDropsTheCache() async {
    let counter = Counter()
    let store = ThumbnailStore(api: StubAPI { _, _ in
        _ = await counter.next()
        return .success(Data([0x01]))
    })

    #expect(await store.data(rkey: "3m2a8twqpv5z2", size: .sm).value != nil)
    await store.clear()
    #expect(await store.data(rkey: "3m2a8twqpv5z2", size: .sm).value != nil)
    #expect(await counter.value == 2)
}
