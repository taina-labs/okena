import Foundation

/// The deep link the box builds, parsed once and purely: the kind is the
/// host component (`convite`, `redefinir`), the token is the path, and the
/// `host` query param carries the box address (url-encoded, so it reads
/// back whole). Any other shape is not ours, and the caller changes
/// nothing when the parse comes back nil.
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
        guard components.scheme?.lowercased() == "taina" else {
            return nil
        }
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
}
