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
