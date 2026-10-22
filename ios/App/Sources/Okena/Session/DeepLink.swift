import Foundation

/// The link the box builds, in either of its two shapes, parsed once and
/// purely: the app's own scheme (`taina://convite/<token>?host=<host>`,
/// the QR's) or the web's (`https://<host>/convite/<token>`, pasted from
/// a message or a browser). The kind is where the token lives, the token
/// is the path, and the box address rides in the `host` query param or
/// the URL's own host. Any other shape is not ours, and the caller
/// changes nothing when the parse comes back nil.
struct DeepLink: Equatable {
    enum Kind: Equatable {
        case invite
        case reset
    }

    let kind: Kind
    let token: String
    let box: String?

    static func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        switch components.scheme?.lowercased() {
        case "taina":
            return native(components)
        case "http", "https":
            return web(components)
        default:
            return nil
        }
    }

    /// The pasted form of the same link, trimmed of the whitespace a copy
    /// picks up along the way.
    static func parse(pasted text: String) -> DeepLink? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return parse(url)
    }

    /// The app's own scheme: the kind is the host component, the token is
    /// the path, and the `host` query param carries the box address
    /// (url-encoded, so it reads back whole).
    private static func native(_ components: URLComponents) -> DeepLink? {
        let kind: Kind
        switch components.host?.lowercased() {
        case "convite": kind = .invite
        case "redefinir": kind = .reset
        default: return nil
        }

        // The path is /<token>: one piece, after the root.
        var path = components.path
        guard path.hasPrefix("/") else { return nil }
        path.removeFirst()
        guard !path.isEmpty, !path.contains("/") else { return nil }

        let box = components.queryItems?
            .first { $0.name == "host" }?
            .value
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        return DeepLink(kind: kind, token: path, box: box)
    }

    /// The web's own link, pasted: the box address is the URL's own
    /// scheme, host and port, the kind is the first path piece and the
    /// token is the second. The scheme is kept as it came: the pilot box
    /// answers plain http, and the address is shown with its caveat.
    private static func web(_ components: URLComponents) -> DeepLink? {
        let pieces = components.path.split(separator: "/")
        guard pieces.count == 2 else { return nil }
        let kind: Kind
        switch pieces[0].lowercased() {
        case "convite": kind = .invite
        case "redefinir": kind = .reset
        default: return nil
        }

        var address = URLComponents()
        address.scheme = components.scheme
        address.host = components.host
        address.port = components.port
        guard let box = address.url?.absoluteString, !box.isEmpty else { return nil }
        return DeepLink(kind: kind, token: String(pieces[1]), box: box)
    }
}
