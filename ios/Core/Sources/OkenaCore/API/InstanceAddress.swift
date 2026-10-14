import Foundation

/// The community's box address, validated before anything touches the
/// network. One box serves one community, so there is one address.
///
/// The box is reached over HTTPS through its own Caddy in the normal
/// install, and a pilot box on the LAN is reached by name. Allowing
/// cleartext to arbitrary hosts would be a downgrade, so `http` is accepted
/// only for local addresses.
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
        if components.scheme == "http" && !isLocal(host) {
            return .failure(.invalidAddress(.insecure))
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

    /// Cleartext cannot leak past the LAN when the name cannot leave it:
    /// localhost, an unqualified name, a `.local` name, or a private or
    /// loopback IP literal.
    private static func isLocal(_ host: String) -> Bool {
        var lowered = host.lowercased()
        // URLComponents keeps the brackets of an IPv6 literal.
        if lowered.hasPrefix("["), lowered.hasSuffix("]") {
            lowered = String(lowered.dropFirst().dropLast())
        }
        if lowered == "localhost" || (!lowered.contains(".") && !lowered.contains(":")) {
            return true
        }
        if lowered.hasSuffix(".local") {
            return true
        }
        if lowered == "::1" || lowered.hasPrefix("fe80:") || lowered.hasPrefix("fd") {
            return true
        }
        return isPrivateIPv4(lowered)
    }

    private static func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        switch (parts[0], parts[1]) {
        case (10, _), (127, _), (169, 254), (192, 168):
            return true
        case (172, 16...31):
            return true
        default:
            return false
        }
    }
}
