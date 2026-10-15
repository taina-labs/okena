import Foundation
import Testing

@testable import OkenaCore

private let assembleiaRkey = "3kx2n8pqrv5w2"
private let estatutoRkey = "3m2a8twqpv5z2"

@Test func loginThenContentsReturnsTheSeededFolders() async throws {
    let fake = FakeTainaAPI()

    let session = try #require(await fake.createSession(username: "ana", password: "segredo", deviceName: "iPhone da Ana").value)
    #expect(session.token.hasPrefix("tnd_"))
    #expect(session.token.count == "tnd_".count + 32)
    #expect(session.me.username == "ana")
    #expect(session.tekoa.name == "Tekoa Sapukai")

    let contents = try #require(await fake.folderContents(folderRkey: nil, limit: nil, cursor: nil, sort: nil).value)
    #expect(contents.folders.map(\.name) == ["Documentos da assembleia", "Fotos da festa"])
    #expect(contents.items.count == 2)

    let me = try #require(await fake.me().value)
    #expect(me.ava.username == "ana")
}

@Test func semAcessoAnswers401() async {
    guard case .api(let apiError) = await FakeTainaAPI().createSession(username: "sem-acesso", password: "x", deviceName: "Teste").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isUnauthorized)
    #expect(apiError.code == "invalid_credentials")
    #expect(!apiError.message.isEmpty)
}

@Test func emptyUsernameAnswersValidationFailed() async {
    guard case .api(let apiError) = await FakeTainaAPI().createSession(username: "", password: "x", deviceName: "Teste").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isValidationFailed)
}

@Test func uploadGrowsTheFolder() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    let before = try #require(await fake.folderContents(folderRkey: assembleiaRkey, limit: nil, cursor: nil, sort: nil).value)
    #expect(before.items.count == 1)

    let source = FileManager.default.temporaryDirectory
        .appending(path: "fake-upload-\(UUID().uuidString).pdf")
    try Data("%PDF-1.4\nregimento\n".utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }

    let uploaded = try #require(await fake.upload(fileAt: source, name: "regimento.pdf", mime: "application/pdf", folderRkey: assembleiaRkey).value)
    #expect(uploaded.name == "regimento.pdf")
    #expect(uploaded.zona == .casa)
    #expect(uploaded.folder == assembleiaRkey)
    #expect(uploaded.sha256.count == 64)
    #expect(uploaded.rkey.count == 13)

    let after = try #require(await fake.folderContents(folderRkey: assembleiaRkey, limit: nil, cursor: nil, sort: nil).value)
    #expect(after.items.count == 2)
    #expect(after.items.last?.name == "regimento.pdf")
}

@Test func uploadToAnUnknownFolderAnswersNotFound() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    let source = FileManager.default.temporaryDirectory
        .appending(path: "fake-upload-\(UUID().uuidString).pdf")
    try Data("BYTES".utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }

    guard case .api(let apiError) = await fake.upload(fileAt: source, name: "x.pdf", mime: "application/pdf", folderRkey: "3aaaa2aaaaaaa").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isNotFound)
}

@Test func thumbnailForANonImageAnswersNotFound() async {
    guard case .api(let apiError) = await FakeTainaAPI().thumbnail(rkey: estatutoRkey, size: .sm).error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isNotFound)
}

@Test func downloadWritesTheSeededBytesToATempFile() async throws {
    let url = try #require(await FakeTainaAPI().download(rkey: estatutoRkey).value)
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(try String(contentsOf: url, encoding: .utf8).hasPrefix("%PDF-1.4"))
}

@Test func createFolderAcceptsThenLists() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    let folder = try #require(await fake.createFolder(name: "Prestação de contas", parentRkey: nil).value)
    #expect(folder.zona == .casa)

    let listed = try #require(await fake.listFolders().value)
    #expect(listed.last?.name == "Prestação de contas")
}

@Test func revokeSessionThenMeAnswersUnauthorized() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)
    #expect(await fake.revokeSession().value != nil)

    guard case .api(let apiError) = await fake.me().error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isUnauthorized)
}

@Test func sliceClampsTheLimitAndReadsTheOffsetCursor() {
    let values = [1, 2, 3]

    let first = Page.slice(of: values, limit: 2, cursor: nil)
    #expect(first.items == [1, 2])
    #expect(first.nextCursor == "2")

    let last = Page.slice(of: values, limit: 2, cursor: "2")
    #expect(last.items == [3])
    #expect(last.nextCursor == nil)

    let beyond = Page.slice(of: values, limit: 2, cursor: "9")
    #expect(beyond.items.isEmpty)
    #expect(beyond.nextCursor == nil)

    let clamped = Page.slice(of: values, limit: 0, cursor: nil)
    #expect(clamped.items == [1])
}

@Test func deletingAFileMovesItToTheTrashAndRestoreBringsItBack() async throws {
    let fake = FakeTainaAPI()

    #expect(await fake.deleteFile(rkey: estatutoRkey).value != nil)

    let contents = try #require(await fake.folderContents(folderRkey: assembleiaRkey, limit: nil, cursor: nil, sort: nil).value)
    #expect(!contents.items.contains { $0.rkey == estatutoRkey })

    let trash = try #require(await fake.trash(limit: nil, cursor: nil).value)
    #expect(trash.items.map(\.rkey) == [estatutoRkey])

    let restored = try #require(await fake.restoreFile(rkey: estatutoRkey).value)
    #expect(restored.deletedAt == nil)

    let empty = try #require(await fake.trash(limit: nil, cursor: nil).value)
    #expect(empty.items.isEmpty)
}

@Test func updateFolderRenamesAndPublishes() async throws {
    let fake = FakeTainaAPI()

    let published = try #require(await fake.updateFolder(rkey: assembleiaRkey, name: nil, zona: .praca).value)
    #expect(published.name == "Documentos da assembleia")
    #expect(published.zona == .praca)

    let renamed = try #require(await fake.updateFolder(rkey: assembleiaRkey, name: "Atas", zona: nil).value)
    #expect(renamed.name == "Atas")
    #expect(renamed.zona == .praca)
}

@Test func movingAFolderIntoItsOwnSubtreeConflicts() async throws {
    let fake = FakeTainaAPI()
    let inner = try #require(await fake.createFolder(name: "Pasta de dentro", parentRkey: assembleiaRkey).value)

    guard case .api(let apiError) = await fake.moveFolder(rkey: assembleiaRkey, parentRkey: inner.rkey).error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isConflict)

    // Moving it out again is fine.
    #expect(await fake.moveFolder(rkey: inner.rkey, parentRkey: nil).value != nil)
}

@Test func deletingAFolderDeletesTheWholeSubtree() async throws {
    let fake = FakeTainaAPI()
    let inner = try #require(await fake.createFolder(name: "Pasta de dentro", parentRkey: assembleiaRkey).value)

    #expect(await fake.deleteFolder(rkey: assembleiaRkey).value != nil)

    let listed = try #require(await fake.listFolders().value)
    #expect(!listed.contains { $0.rkey == assembleiaRkey || $0.rkey == inner.rkey })

    let trash = try #require(await fake.trash(limit: nil, cursor: nil).value)
    #expect(trash.items.contains { $0.rkey == estatutoRkey })
}

@Test func photosPaginateByCursor() async throws {
    let fake = FakeTainaAPI()

    let first = try #require(await fake.photos(limit: 1, cursor: nil).value)
    #expect(first.items.count == 1)
    #expect(first.nextCursor == "1")

    let second = try #require(await fake.photos(limit: 1, cursor: first.nextCursor).value)
    #expect(second.items.count == 1)
    #expect(second.items.first?.rkey != first.items.first?.rkey)

    let third = try #require(await fake.photos(limit: 1, cursor: second.nextCursor).value)
    #expect(third.items.count == 1)
    #expect(third.nextCursor == nil)
}

@Test func theTimelineGroupsTheVisualFilesByDay() async throws {
    let fake = FakeTainaAPI()

    let page = try #require(await fake.photoTimeline(limit: nil, cursor: nil).value)
    #expect(page.items.map(\.date) == ["2026-06-21"])
    #expect(page.items.first?.photos.count == 3)
    #expect(page.nextCursor == nil)
}

@Test func theAccessFlowRunsFromRequestToDecision() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    let pedido = try #require(await fake.requestAccess(fileRkey: estatutoRkey, motivo: "Para a reuniao.").value)
    #expect(pedido.status == .pendente)
    #expect(pedido.motivo == "Para a reuniao.")
    #expect(pedido.pedinte?.username == "ana")

    let mine = try #require(await fake.myRequests().value)
    #expect(mine.items.first?.publicId == pedido.publicId)

    let concessao = try #require(await fake.approveRequest(id: "ped3xk9mq2v7w4").value)
    #expect(concessao.leitor?.username == "joana")
    #expect(concessao.recurso == estatutoRkey)

    let received = try #require(await fake.accessRequests().value)
    #expect(received.items.first?.status == .aprovado)

    guard case .api(let conflict) = await fake.approveRequest(id: "ped3xk9mq2v7w4").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(conflict.isConflict)
}

@Test func denyClosesThePedidoWithoutAccess() async throws {
    let fake = FakeTainaAPI()

    let pedido = try #require(await fake.denyRequest(id: "ped3xk9mq2v7w4").value)
    #expect(pedido.status == .negado)
    #expect(pedido.decididoEm != nil)
}

@Test func storageCountsTheTrashAsItIs() async throws {
    let fake = FakeTainaAPI()

    let before = try #require(await fake.storage().value)
    #expect(before.trash.count == 0)
    #expect(before.quotaBytes == 268_435_456_000)

    #expect(await fake.deleteFile(rkey: estatutoRkey).value != nil)

    let after = try #require(await fake.storage().value)
    #expect(after.trash.count == 1)
    #expect(after.trash.bytes == 48_213)
}

@Test func membersListTheZeladorasFirst() async throws {
    let fake = FakeTainaAPI()

    let page = try #require(await fake.members().value)
    #expect(page.items.first?.papel == .zelador)
    #expect(page.items.map(\.username) == ["ana", "joana", "rafael"])
}

@Test func devicesListTheNewestFirstAndRevocationMarksTheClock() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "iPhone da Ana").value != nil)

    let devices = try #require(await fake.devices().value)
    #expect(devices.count == 2)
    #expect(devices.first?.name == "iPhone da Ana")
    #expect(devices.first?.revokedAt == nil)

    let id = devices[0].publicId
    #expect(await fake.revokeDevice(id: id).value != nil)

    let after = try #require(await fake.devices().value)
    #expect(after.first { $0.publicId == id }?.revokedAt != nil)

    guard case .api(let apiError) = await fake.revokeDevice(id: "dev-nao-existe").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isNotFound)
}

@Test func theMuralListsTheSeededChainNewestFirst() async throws {
    let fake = FakeTainaAPI()

    let page = try #require(await fake.mural(limit: 2, cursor: nil).value)
    #expect(page.items.map(\.seq) == [4, 3])
    #expect(page.nextCursor == "2")

    let rest = try #require(await fake.mural(limit: nil, cursor: page.nextCursor).value)
    #expect(rest.items.map(\.seq) == [2, 1])
    #expect(rest.items.last?.prev == nil)
    #expect(rest.nextCursor == nil)
}

@Test func saudeCarriesTheLastBackup() async throws {
    let fake = FakeTainaAPI()

    let saude = try #require(await fake.saude().value)
    #expect(saude.backup.at != nil)
    #expect(saude.jobs["backups"] == 0)
    #expect(saude.storage.files == 5)
}
