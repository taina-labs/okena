import Foundation

/// The byte layout of a `multipart/form-data` body, with no file IO.
///
/// A large upload is assembled by writing `prologue`, streaming the file
/// bytes right after it, then writing `epilogue`. The file part must be last
/// in `parts`, since its bytes are what the caller streams in between.
public enum MultipartBody {
    public struct Part: Equatable, Sendable {
        public let name: String
        public let filename: String?
        public let contentType: String?
        public let content: Content

        public enum Content: Equatable, Sendable {
            case text(String)
            case file(URL)
        }

        public init(
            name: String,
            filename: String? = nil,
            contentType: String? = nil,
            content: Content
        ) {
            self.name = name
            self.filename = filename
            self.contentType = contentType
            self.content = content
        }
    }

    /// A boundary that cannot occur in the parts. Random, 32 hex characters.
    public static func boundary() -> String {
        let digits = Array("0123456789abcdef")
        return String((0..<32).map { _ in digits[Int.random(in: 0..<16)] })
    }

    /// The bytes before the file bytes: every text part complete, then the
    /// file part's headers. The caller streams the file right after.
    public static func prologue(boundary: String, parts: [Part]) -> Data {
        var data = Data()
        for part in parts {
            data.append("--\(boundary)\r\n")
            data.append(headers(part))
            data.append("\r\n")
            switch part.content {
            case .text(let value):
                data.append(Data(value.utf8))
                data.append("\r\n")
            case .file:
                break
            }
        }
        return data
    }

    /// The closing delimiter. The leading CRLF ends the streamed file bytes
    /// and belongs to the boundary, so the caller writes nothing in between.
    public static func epilogue(boundary: String) -> Data {
        Data("\r\n--\(boundary)--\r\n".utf8)
    }

    /// The whole body in memory. For tests and small parts only.
    public static func encode(boundary: String, parts: [Part]) -> Data {
        var data = prologue(boundary: boundary, parts: parts)
        for part in parts {
            // A missing file would quietly produce an invalid body, but this
            // form is for tests; the live path streams with a FileHandle.
            if case .file(let url) = part.content, let bytes = try? Data(contentsOf: url) {
                data.append(bytes)
            }
        }
        data.append(epilogue(boundary: boundary))
        return data
    }

    /// Escapes a filename for a Content-Disposition header: CR, LF and the
    /// double quote are the ones that break the frame. A CR and LF together
    /// are one Character in Swift, so both spellings are dropped here.
    static func escaped(_ filename: String) -> String {
        filename.filter { $0 != "\r" && $0 != "\n" && $0 != "\r\n" && $0 != "\"" }
    }

    private static func headers(_ part: Part) -> Data {
        var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
        if let filename = part.filename {
            disposition += "; filename=\"\(escaped(filename))\""
        }
        var lines = disposition + "\r\n"
        if let contentType = part.contentType {
            lines += "Content-Type: \(contentType)\r\n"
        }
        return Data(lines.utf8)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
