import Foundation
import Testing

@testable import OkenaCore

private struct StubAPI: TainaAPI {
    let thumbnailAnswer: @Sendable (String, ThumbnailSize) async -> TainaResult<Data>

    func instance() async -> TainaResult<Instance> { .failure(.cancelled) }
    func createSession(username: String, password: String, deviceName: String) async -> TainaResult<Session> { .failure(.cancelled) }
    func revokeSession() async -> TainaResult<Void> { .failure(.cancelled) }
    func me() async -> TainaResult<Me> { .failure(.cancelled) }
    func listFolders() async -> TainaResult<[Folder]> { .failure(.cancelled) }
    func createFolder(name: String, parentRkey: String?) async -> TainaResult<Folder> { .failure(.cancelled) }
    func folderContents(folderRkey: String?, limit: Int?, cursor: String?, sort: Sort?) async -> TainaResult<FolderContents> { .failure(.cancelled) }
    func upload(fileAt url: URL, name: String, mime: String, folderRkey: String?) async -> TainaResult<File> { .failure(.cancelled) }
    func download(rkey: String) async -> TainaResult<URL> { .failure(.cancelled) }

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
