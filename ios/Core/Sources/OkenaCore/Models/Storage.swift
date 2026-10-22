import Foundation

/// The portrait of the storage that `GET /storage` answers with.
public struct StorageStats: Decodable, Sendable, Equatable {
    /// Bytes at rest, by kind of content.
    public struct ByKind: Decodable, Sendable, Equatable {
        public let photos: Int64
        public let videos: Int64
        public let documents: Int64
        public let others: Int64
    }

    /// What sits in the trash: how many items and the bytes they hold.
    public struct Trash: Decodable, Sendable, Equatable {
        public let count: Int64
        public let bytes: Int64
    }

    public let usedBytes: Int64
    public let quotaBytes: Int64?
    public let byKind: ByKind
    public let files: Int64
    public let photos: Int64
    public let trash: Trash
}

/// The community's health panel: storage, queued work and the last backup,
/// in plain words.
public struct Saude: Decodable, Sendable, Equatable {
    /// When the last backup ran and how much it carried; never, so far.
    public struct Backup: Decodable, Sendable, Equatable {
        public let at: String?
        public let bytes: Int64?
    }

    public let storage: StorageStats
    /// Work waiting or running, by queue.
    public let jobs: [String: Int64]
    public let backup: Backup
}
