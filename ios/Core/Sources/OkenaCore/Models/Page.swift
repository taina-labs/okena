import Foundation

/// The uniform list envelope: `{"items": [...], "next_cursor": ...}`. The
/// cursor is opaque on keyset lists and a decimal offset in string form on
/// offset lists; null at the end.
public struct Page<Value: Decodable & Sendable>: Decodable, Sendable {
    public let items: [Value]
    public let nextCursor: String?

    public init(items: [Value], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

extension Page {
    /// Slices a full, ordered list into one page, walking it by the offset
    /// cursor the contract allows. The server does this for the real lists;
    /// `FakeTainaAPI` runs the same rule in memory so previews scroll for
    /// real. Pure: values, limit, cursor, page.
    static func slice(of values: [Value], limit: Int?, cursor: String?) -> Page<Value> {
        // The contract's limits: 50 by default, never below 1 or above 100.
        let size = limit.map { min(max($0, 1), 100) } ?? 50
        let start = cursor.flatMap(Int.init) ?? 0
        guard start < values.count else {
            return Page(items: [], nextCursor: nil)
        }
        let end = min(start + size, values.count)
        return Page(
            items: Array(values[start..<end]),
            nextCursor: end < values.count ? String(end) : nil
        )
    }
}

/// The contents of one folder: folders come complete, only the files
/// paginate.
public struct FolderContents: Decodable, Sendable, Equatable {
    public let folders: [Folder]
    public let items: [File]
    public let nextCursor: String?
}
