import Foundation

/// The community's box address, validated before anything touches the
/// network. One box serves one community, so there is one address.
///
/// The person types where their box lives, and the app cannot know that at
/// build time, so `http` is accepted for any host. What it is not is silent:
/// `isCleartext` is what the screens read to say so. A rule that only trust
/// "local" names was tried first and it refused real boxes: a tailnet name
/// such as `taina.yby` is fully qualified, and it is exactly where a pilot
/// box lives. Over a private network (a tailnet, a VPN) the path is already
/// encrypted under the app's feet; over an open one it is not, and the person
/// owns both ends, so the decision is theirs and it is stated out loud.
public struct InstanceAddress: Equatable, Sendable {
    /// Always scheme and host, no path, no query, no fragment.
    public let url: URL

    init(url: URL) {
        self.url = url
    }

    /// What a person typed, tightened: whitespace trimmed, https by default,
    /// one trailing slash dropped.
    public static func parse(input: String) -> TainaResult<InstanceAddress> {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return .failure(.invalidAddress(.empty))
        }
        if !text.contains("://") {
            text = "https://" + text
        }
        if text.hasSuffix("/") && !text.hasSuffix("://") {
            text.removeLast()
        }

        guard let components = URLComponents(string: text) else {
            return .failure(.invalidAddress(.malformed))
        }
        guard components.scheme == "http" || components.scheme == "https" else {
            return .failure(.invalidAddress(.unsupportedScheme))
        }
        guard let host = components.host, !host.isEmpty else {
            return .failure(.invalidAddress(.malformed))
        }
        if components.user != nil || components.password != nil {
            return .failure(.invalidAddress(.malformed))
        }

        var clean = URLComponents()
        clean.scheme = components.scheme
        clean.host = host
        clean.port = components.port
        guard let url = clean.url else {
            return .failure(.invalidAddress(.malformed))
        }
        return .success(InstanceAddress(url: url))
    }

    /// The host, for display: "taina.minhacasa.ts.net".
    public var display: String {
        url.host() ?? ""
    }

    /// The box answers without TLS. Shown wherever the host is, never hidden.
    public var isCleartext: Bool {
        url.scheme?.lowercased() == "http"
    }
}
