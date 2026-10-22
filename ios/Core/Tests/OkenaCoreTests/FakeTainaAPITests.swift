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

@Test func theInviteFlowRunsFromProbeToAccount() async throws {
    let fake = FakeTainaAPI()

    let status = try #require(await fake.inviteStatus(token: "tk9x2m5qp7w4v8").value)
    #expect(status.valid)

    let session = try #require(await fake.acceptInvite(token: "tk9x2m5qp7w4v8", username: "joao", password: "segredo", displayName: "João Mendes", deviceName: "iPhone do João").value)
    #expect(session.token.hasPrefix("tnd_"))
    #expect(session.me.username == "joao")
    #expect(session.me.displayName == "João Mendes")
    #expect(session.me.papel == .morador)

    let me = try #require(await fake.me().value)
    #expect(me.ava.username == "joao")

    let devices = try #require(await fake.devices().value)
    #expect(devices.first?.name == "iPhone do João")
}

@Test func anEmptyUsernameOnTheInviteAnswersValidationFailed() async {
    guard case .api(let apiError) = await FakeTainaAPI().acceptInvite(token: "tk9x2m5qp7w4v8", username: "", password: "segredo", displayName: nil, deviceName: "Teste").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isValidationFailed)
    #expect(apiError.details["username"]?.isEmpty == false)
}

@Test func theResetFlowSignsTheMoradoraIn() async throws {
    let fake = FakeTainaAPI()

    let status = try #require(await fake.resetStatus(token: "tk9x2m5qp7w4v8").value)
    #expect(status.valid)

    let session = try #require(await fake.resetPassword(token: "tk9x2m5qp7w4v8", password: "nova-senha", deviceName: "iPhone da Joana").value)
    #expect(session.me.username == "joana")

    let me = try #require(await fake.me().value)
    #expect(me.ava.username == "joana")
}

/// The fake's dead token closes every door with the 401 the box answers,
/// so the dead ends of both screens preview.
@Test func theExpiredTokenClosesEveryDoor() async {
    let fake = FakeTainaAPI()
    for result in [
        await fake.inviteStatus(token: "expirado").error,
        await fake.resetStatus(token: "expirado").error,
        await fake.acceptInvite(token: "expirado", username: "joao", password: "segredo", displayName: nil, deviceName: "Teste").error,
        await fake.resetPassword(token: "expirado", password: "segredo", deviceName: "Teste").error,
    ] {
        guard case .api(let apiError) = result else {
            #expect(Bool(false), "expected .api")
            continue
        }
        #expect(apiError.isUnauthorized)
        #expect(apiError.code == "invalid_token")
    }
}

// MARK: the manifest and the batch

@Test func theManifestListsEveryLivingFileOldestFirstAndWalksByRkey() async throws {
    let fake = FakeTainaAPI()

    let first = try #require(await fake.manifest(after: nil, limit: 2).value)
    #expect(first.items.map(\.rkey) == ["3m2a8twqpv5z2", "3m5c9vxyq2b7t"])
    #expect(first.nextCursor == "3m5c9vxyq2b7t")

    let second = try #require(await fake.manifest(after: first.nextCursor, limit: 2).value)
    #expect(second.items.map(\.rkey) == ["3m7d1wyzr4c8u", "3m8e2xz0s5d9v"])
    #expect(second.nextCursor == "3m8e2xz0s5d9v")

    let end = try #require(await fake.manifest(after: second.nextCursor, limit: 2).value)
    #expect(end.items.map(\.rkey) == ["3m9f4xk1q7v2n"])
    #expect(end.nextCursor == nil)

    // The trash is not a backup: a deleted file is not in the manifest.
    #expect(await fake.deleteFile(rkey: estatutoRkey).value != nil)
    let afterTrash = try #require(await fake.manifest(after: nil, limit: nil).value)
    #expect(!afterTrash.items.contains { $0.rkey == estatutoRkey })
}

@Test func theBatchAppliesEveryItemAndSaysWhatBecameOfEach() async throws {
    let fake = FakeTainaAPI()

    // One id that fails (nobody's file here fails on zone, so an unknown
    // one stands in) and one that works: the batch does not stop.
    let outcomes = try #require(await fake.batch(op: .trash, ids: [estatutoRkey, "3zzzzzzzzzzzz"], folderRkey: nil).value)
    #expect(outcomes.first?.ok == true)
    #expect(outcomes.first?.file?.deletedAt != nil)
    #expect(outcomes.last?.ok == false)
    #expect(outcomes.last?.error == "not_found")

    // The trash answers, and the restore brings it back by the same door.
    let restored = try #require(await fake.batch(op: .restore, ids: [estatutoRkey], folderRkey: nil).value)
    #expect(restored.first?.ok == true)
    #expect(restored.first?.file?.deletedAt == nil)

    let published = try #require(await fake.batch(op: .publish, ids: [estatutoRkey], folderRkey: nil).value)
    #expect(published.first?.file?.zona == .praca)

    let unpublished = try #require(await fake.batch(op: .unpublish, ids: [estatutoRkey], folderRkey: nil).value)
    #expect(unpublished.first?.file?.zona == .casa)

    let moved = try #require(await fake.batch(op: .move, ids: [estatutoRkey], folderRkey: assembleiaRkey).value)
    #expect(moved.first?.file?.folder == assembleiaRkey)
}

@Test func theBatchRefusesMoreThanTwoHundredIds() async {
    let ids = (0...200).map { "3m2a8twqpv5z\($0)" }
    guard case .api(let apiError) = await FakeTainaAPI().batch(op: .trash, ids: ids, folderRkey: nil).error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isValidationFailed)
}

// MARK: the grants

@Test func theGrantsListBothSidesOfTheCaller() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    let given = try #require(await fake.grants(role: .owner).value)
    #expect(given.items.map(\.publicId) == ["con3qk9mq2v7w1"])
    #expect(given.items.first?.dono?.username == "ana")

    let received = try #require(await fake.grants(role: .reader).value)
    #expect(received.items.map(\.publicId) == ["con5rk2mq8v3w7"])
    #expect(received.items.first?.revogadaEm != nil)
}

@Test func revokingMarksTheClockOnceAndConflictsTheSecondTime() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    #expect(await fake.revokeGrant(id: "con3qk9mq2v7w1").value != nil)
    let given = try #require(await fake.grants(role: .owner).value)
    #expect(given.items.first?.revogadaEm != nil)

    guard case .api(let apiError) = await fake.revokeGrant(id: "con3qk9mq2v7w1").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isConflict)
    #expect(apiError.code == "invalid_status")

    guard case .api(let missing) = await fake.revokeGrant(id: "con-nao-existe").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(missing.isNotFound)
}

// MARK: the password change

@Test func thePasswordChangeSaysWhatTheBoxWouldSay() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    #expect(await fake.updatePassword(current: "qualquer", new: "nova-senha").value != nil)

    guard case .api(let wrong) = await fake.updatePassword(current: "errada", new: "nova-senha").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(wrong.code == "invalid_credentials")
    #expect(wrong.status == 403)

    guard case .api(let weak) = await fake.updatePassword(current: "qualquer", new: "curta").error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(weak.isValidationFailed)
}

// MARK: the zeladora's acts

@Test func theZeladoraRunsTheWholeRoster() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    // The invite: the link carries the token and the box's own domain.
    let invite = try #require(await fake.inviteMember(papel: .morador).value)
    #expect(invite.ava.username == nil)
    #expect(invite.inviteUrl.hasPrefix("taina://convite/\(invite.token)?host="))

    // A pending invite can be taken back, once.
    #expect(await fake.revokeInvite(id: invite.ava.publicId).value != nil)
    let roster = try #require(await fake.members().value)
    #expect(!roster.items.contains { $0.publicId == invite.ava.publicId })

    // The role change; the last zeladora cannot step down.
    let joana = "avaq7r2m5xk9p1"
    let promoted = try #require(await fake.updateMember(id: joana, papel: .zelador).value)
    #expect(promoted.papel == .zelador)

    // The password link of one person.
    let link = try #require(await fake.memberResetLink(id: joana).value)
    #expect(link.resetUrl.hasPrefix("taina://redefinir/\(link.token)?host="))
    #expect(link.ava.username == "joana")

    // Off and on again.
    #expect(await fake.deactivateMember(id: joana).value != nil)
    let off = try #require(await fake.members().value)
    #expect(off.items.first { $0.publicId == joana }?.deactivatedAt != nil)
    let back = try #require(await fake.reactivateMember(id: joana).value)
    #expect(back.deactivatedAt == nil)
}

@Test func theLastZeladoraCannotStepDown() async throws {
    let fake = FakeTainaAPI()
    #expect(await fake.createSession(username: "ana", password: "segredo", deviceName: "Teste").value != nil)

    // Ana is the only zeladora of the fake's world.
    guard case .api(let apiError) = await fake.updateMember(id: "avap2xw5m8q3", papel: .morador).error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isConflict)
    #expect(apiError.code == "last_zelador")
}

@Test func theQuotaChangesAndRefusesNothingAtAll() async throws {
    let fake = FakeTainaAPI()

    let tekoa = try #require(await fake.setQuota(bytes: 536_870_912_000).value)
    #expect(tekoa.storageQuotaBytes == 536_870_912_000)

    let stats = try #require(await fake.storage().value)
    #expect(stats.quotaBytes == 536_870_912_000)

    guard case .api(let apiError) = await fake.setQuota(bytes: 0).error else {
        #expect(Bool(false), "expected .api")
        return
    }
    #expect(apiError.isValidationFailed)
}

@Test func theBackupTriggerIsTheQueueNotTheBackup() async throws {
    #expect(await FakeTainaAPI().triggerBackup().value != nil)
}
