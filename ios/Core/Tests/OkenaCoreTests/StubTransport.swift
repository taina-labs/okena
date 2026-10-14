import Foundation

@testable import OkenaCore

/// One call a transport saw.
enum Call: Sendable {
    case send(URLRequest)
    case upload(URLRequest, URL)
    case download(URLRequest)
}

/// A transport that answers from a closure and records every call, for
/// tests.
struct StubTransport: Transport {
    let handler: @Sendable (Call) async -> TainaResult<HTTPResponse>
    let recorder: Recorder

    init(handler: @escaping @Sendable (Call) async -> TainaResult<HTTPResponse>) {
        self.handler = handler
        recorder = Recorder()
    }

    func send(_ request: URLRequest) async -> TainaResult<HTTPResponse> {
        await recorder.record(.send(request))
        return await handler(.send(request))
    }

    func upload(_ request: URLRequest, fromFile file: URL) async -> TainaResult<HTTPResponse> {
        await recorder.record(.upload(request, file))
        return await handler(.upload(request, file))
    }

    func download(_ request: URLRequest) async -> TainaResult<HTTPResponse> {
        await recorder.record(.download(request))
        return await handler(.download(request))
    }
}

/// Everything a stub saw, in order.
actor Recorder {
    private(set) var calls: [Call] = []

    func record(_ call: Call) {
        calls.append(call)
    }

    func requests() -> [URLRequest] {
        calls.map { call in
            switch call {
            case .send(let request): request
            case .upload(let request, _): request
            case .download(let request): request
            }
        }
    }
}

func http(
    _ url: URL?,
    _ status: Int,
    body: String = "",
    headers: [String: String] = [:],
    fileURL: URL? = nil
) -> HTTPResponse {
    let response = HTTPURLResponse(
        url: url ?? URL(string: "https://example.com")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers
    )!
    if let fileURL {
        return HTTPResponse(fileURL: fileURL, response: response)
    }
    return HTTPResponse(data: Data(body.utf8), response: response)
}

actor Counter {
    private(set) var value = 0

    func next() -> Int {
        value += 1
        return value
    }
}
