import Foundation

/// The uniform list envelope: `{"items": [...], "next_cursor": ...}`. The
/// cursor is opaque on keyset lists and a decimal offset in string form on
/// offset lists; null at the end.
struct Page<Value: Decodable & Sendable>: Decodable, Sendable {
    let items: [Value]
    let nextCursor: String?
}

/// The contents of one folder: folders come complete, only the files
/// paginate.
public struct FolderContents: Decodable, Sendable, Equatable {
    public let folders: [Folder]
    public let items: [File]
    public let nextCursor: String?
}
