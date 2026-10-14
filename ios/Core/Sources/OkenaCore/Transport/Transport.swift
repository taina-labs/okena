import Foundation

/// One HTTP round trip. For `send` and `upload` the body is `data`; for
/// `download` the body is on disk at `fileURL` and `data` is empty, so a
/// video is never held in memory.
public struct HTTPResponse: Sendable {
    public let data: Data
    public let response: HTTPURLResponse
    public let fileURL: URL?

    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
        self.fileURL = nil
    }

    /// The caller already owns the file at `fileURL`.
    public init(fileURL: URL, response: HTTPURLResponse) {
        self.data = Data()
        self.response = response
        self.fileURL = fileURL
    }

    public var status: Int {
        response.statusCode
    }

    public var body: String {
        String(decoding: data, as: UTF8.self)
    }

    public var isSuccess: Bool {
        (200..<300).contains(status)
    }

    /// The header, case-insensitively, or nil.
    public func header(_ name: String) -> String? {
        response.value(forHTTPHeaderField: name)
    }
}

/// The only seam that touches the network. Everything above it takes a
/// `Transport`, so the whole client is testable with a stub and no sockets.
public protocol Transport: Sendable {
    /// Everything that carries JSON in and out.
    func send(_ request: URLRequest) async -> TainaResult<HTTPResponse>

    /// A request body that already lives in a file: `URLSession` streams it
    /// from disk, so a 2 GiB upload is never held in memory.
    func upload(_ request: URLRequest, fromFile file: URL) async -> TainaResult<HTTPResponse>

    /// The response written to a file, with its status and headers, so the
    /// caller can name it and move it where it wants.
    func download(_ request: URLRequest) async -> TainaResult<HTTPResponse>
}

public struct URLSessionTransport: Transport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async -> TainaResult<HTTPResponse> {
        let outcome: (Data, URLResponse)
        do {
            outcome = try await session.data(for: request)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
        return Self.assembled(data: outcome.0, response: outcome.1)
    }

    public func upload(_ request: URLRequest, fromFile file: URL) async -> TainaResult<HTTPResponse> {
        let outcome: (Data, URLResponse)
        do {
            outcome = try await session.upload(for: request, fromFile: file)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
        return Self.assembled(data: outcome.0, response: outcome.1)
    }

    public func download(_ request: URLRequest) async -> TainaResult<HTTPResponse> {
        let outcome: (URL, URLResponse)
        do {
            outcome = try await session.download(for: request)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
        guard let http = outcome.1 as? HTTPURLResponse else {
            return .failure(.invalidResponse("not an HTTP response"))
        }

        // URLSession deletes its temp file when it goes out of scope, so the
        // file moves to a name we own before returning.
        let kept = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: outcome.0, to: kept)
        } catch {
            return .failure(.network("could not keep the downloaded file: \(error.localizedDescription)"))
        }
        return .success(HTTPResponse(fileURL: kept, response: http))
    }

    private static func assembled(data: Data, response: URLResponse) -> TainaResult<HTTPResponse> {
        guard let http = response as? HTTPURLResponse else {
            return .failure(.invalidResponse("not an HTTP response"))
        }
        return .success(HTTPResponse(data: data, response: http))
    }
}
