import Foundation
import Testing

@testable import OkenaCore

@Test func bodyStartsAndEndsWithTheBoundary() {
    let body = MultipartBody.encode(
        boundary: "BOUNDARY",
        parts: [MultipartBody.Part(name: "folder", content: .text("3kx2n8pqrv5w2"))]
    )
    let text = String(decoding: body, as: UTF8.self)
    #expect(text.hasPrefix("--BOUNDARY\r\n"))
    #expect(text.hasSuffix("--BOUNDARY--\r\n"))
}

@Test func textPartCarriesTheNameWithoutFilename() {
    let text = String(
        decoding: MultipartBody.prologue(
            boundary: "BOUNDARY",
            parts: [MultipartBody.Part(name: "folder", content: .text("3kx2n8pqrv5w2"))]
        ),
        as: UTF8.self
    )
    #expect(text.contains("Content-Disposition: form-data; name=\"folder\"\r\n"))
    #expect(!text.contains("filename="))
    #expect(!text.contains("Content-Type:"))
}

@Test func filePartCarriesFilenameAndContentType() {
    let text = String(
        decoding: MultipartBody.prologue(
            boundary: "BOUNDARY",
            parts: [
                MultipartBody.Part(name: "folder", content: .text("3kx2n8pqrv5w2")),
                MultipartBody.Part(
                    name: "file",
                    filename: "ata.pdf",
                    contentType: "application/pdf",
                    content: .file(URL(fileURLWithPath: "/tmp/nao-existe"))
                ),
            ]
        ),
        as: UTF8.self
    )
    #expect(text.contains("; filename=\"ata.pdf\"\r\n"))
    #expect(text.contains("Content-Type: application/pdf\r\n"))
}

@Test func prologueEndsReadyForTheFileBytes() {
    let text = String(
        decoding: MultipartBody.prologue(
            boundary: "BOUNDARY",
            parts: [
                MultipartBody.Part(name: "folder", content: .text("3kx2n8pqrv5w2")),
                MultipartBody.Part(
                    name: "file",
                    filename: "ata.pdf",
                    contentType: "application/pdf",
                    content: .file(URL(fileURLWithPath: "/tmp/nao-existe"))
                ),
            ]
        ),
        as: UTF8.self
    )
    let expected =
        "--BOUNDARY\r\n" +
        "Content-Disposition: form-data; name=\"folder\"\r\n" +
        "\r\n" +
        "3kx2n8pqrv5w2\r\n" +
        "--BOUNDARY\r\n" +
        "Content-Disposition: form-data; name=\"file\"; filename=\"ata.pdf\"\r\n" +
        "Content-Type: application/pdf\r\n" +
        "\r\n"
    #expect(text == expected)
}

@Test func epilogueClosesTheFrame() {
    let text = String(decoding: MultipartBody.epilogue(boundary: "BOUNDARY"), as: UTF8.self)
    #expect(text == "\r\n--BOUNDARY--\r\n")
}

@Test func hostileFilenameCannotInjectAHeader() {
    let prologue = String(
        decoding: MultipartBody.prologue(
            boundary: "BOUNDARY",
            parts: [
                MultipartBody.Part(
                    name: "file",
                    filename: "ata.pdf\"\r\nContent-Type: text/html\r\nX: ",
                    contentType: "application/pdf",
                    content: .text("bytes")
                )
            ]
        ),
        as: UTF8.self
    )
    #expect(prologue.contains("filename=\"ata.pdfContent-Type: text/htmlX: \""))
    #expect(prologue.components(separatedBy: "Content-Disposition").count - 1 == 1)
}

@Test func encodeCarriesTheFileBytesBetweenPrologueAndEpilogue() throws {
    let source = FileManager.default.temporaryDirectory
        .appending(path: "multipart-\(UUID().uuidString).bin")
    try Data("CONTEUDO-DO-ARQUIVO".utf8).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }

    let body = MultipartBody.encode(
        boundary: "BOUNDARY",
        parts: [
            MultipartBody.Part(name: "folder", content: .text("3kx2n8pqrv5w2")),
            MultipartBody.Part(name: "file", filename: "ata.pdf", contentType: "application/pdf", content: .file(source)),
        ]
    )
    let text = String(decoding: body, as: UTF8.self)
    #expect(text.contains("CONTEUDO-DO-ARQUIVO"))
    #expect(text.hasSuffix("CONTEUDO-DO-ARQUIVO\r\n--BOUNDARY--\r\n"))
}

@Test func boundaryIs32HexAndDiffersBetweenCalls() {
    let first = MultipartBody.boundary()
    let second = MultipartBody.boundary()
    #expect(first.count == 32)
    #expect(first.allSatisfy { $0.isHexDigit })
    #expect(first != second)
}
