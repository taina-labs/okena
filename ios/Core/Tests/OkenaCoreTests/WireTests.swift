import Foundation
import Testing

@testable import OkenaCore

private let fileWithOwnerJSON = """
{"rkey":"3n4b9uxrw6a3","cid":"bp3q4r5s6t7u8v9w0x1y2z3a4b5c6d7e8","blob_cid":"bq4r5s6t7u8v9w0x1y2z3a4b5c6d7e8f9","sha256":"aa11bb22cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66","name":"ata.pdf","mime":"application/pdf","size":19,"zona":"casa","folder":null,"dono":"avap2xw5m8q3","taken_at":null,"width":null,"height":null,"rendition":"none","deleted_at":null,"created_at":"2026-10-14T08:00:00Z","updated_at":"2026-10-14T08:00:00Z"}
"""

private let fileWithoutOwnerJSON = """
{"rkey":"3n4b9uxrw6a3","cid":"bp3q4r5s6t7u8v9w0x1y2z3a4b5c6d7e8","blob_cid":"bq4r5s6t7u8v9w0x1y2z3a4b5c6d7e8f9","sha256":"aa11bb22cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66","name":"ata.pdf","mime":"application/pdf","size":19,"zona":"casa","folder":null,"taken_at":null,"width":null,"height":null,"rendition":"none","deleted_at":null,"created_at":"2026-10-14T08:00:00Z","updated_at":"2026-10-14T08:00:00Z"}
"""

private let folderWithOwnerJSON = """
{"rkey":"3kx2n8pqrv5w2","cid":"bmq2a5xw7k3p9r2t8v4z6c1d5f7h9j2x","name":"Documentos da assembleia","zona":"casa","folder":null,"dono":"avap2xw5m8q3","deleted_at":null,"created_at":"2026-03-10T14:00:00Z","updated_at":"2026-03-10T14:00:00Z"}
"""

private let folderWithoutOwnerJSON = """
{"rkey":"3kx2n8pqrv5w2","cid":"bmq2a5xw7k3p9r2t8v4z6c1d5f7h9j2x","name":"Documentos da assembleia","zona":"casa","folder":null,"deleted_at":null,"created_at":"2026-03-10T14:00:00Z","updated_at":"2026-03-10T14:00:00Z"}
"""

/// The owner on the wire: `dono` read when present, nil when the record
/// carries none (the box answers null when the owner no longer exists).
@Test func fileDecodesTheOwnerWhenPresentAndNilWhenAbsent() throws {
    let owned = try #require(APICoding.decoder.decode(File.self, from: Data(fileWithOwnerJSON.utf8), label: "file").value)
    #expect(owned.dono == "avap2xw5m8q3")

    let ownerless = try #require(APICoding.decoder.decode(File.self, from: Data(fileWithoutOwnerJSON.utf8), label: "file").value)
    #expect(ownerless.dono == nil)
}

@Test func folderDecodesTheOwnerWhenPresentAndNilWhenAbsent() throws {
    let owned = try #require(APICoding.decoder.decode(Folder.self, from: Data(folderWithOwnerJSON.utf8), label: "folder").value)
    #expect(owned.dono == "avap2xw5m8q3")

    let ownerless = try #require(APICoding.decoder.decode(Folder.self, from: Data(folderWithoutOwnerJSON.utf8), label: "folder").value)
    #expect(ownerless.dono == nil)
}
