import Foundation

/// The etag book of the collection reads: one entry per request and
/// session, holding the tag the box sent and the body it named. The box
/// answers 304 with no body, so the body is kept here and handed back
/// when the answer is "not modified". In memory only: a relaunch reads
/// the collections again. The key carries the session token, because the
/// etag is scope-local and another session's tag is not ours to send.
public actor ConditionalStore {
    private struct Entry {
        var tag: String
        var body: Data
    }

    private var entries: [String: Entry] = [:]

    public init() {}

    /// The tag to send as `If-None-Match`, when there is one.
    func tag(for key: String) -> String? {
        entries[key]?.tag
    }

    /// The body the tag named.
    func body(for key: String) -> Data? {
        entries[key]?.body
    }

    /// Remembers the body under the tag the box sent. A 200 without a tag
    /// drops the entry: there is nothing to condition the next read on.
    func keep(tag: String?, body: Data, for key: String) {
        guard let tag, !tag.isEmpty else {
            entries.removeValue(forKey: key)
            return
        }
        entries[key] = Entry(tag: tag, body: body)
    }
}
