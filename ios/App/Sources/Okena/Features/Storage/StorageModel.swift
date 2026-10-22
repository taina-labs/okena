import OkenaCore
import SwiftUI

/// The kind of content a storage line counts: the wire's four buckets.
enum StorageKind: Equatable {
    case photos, videos, documents, others

    var label: String {
        switch self {
        case .photos: "Fotos"
        case .videos: "Vídeos"
        case .documents: "Documentos"
        case .others: "Outros"
        }
    }
}

/// The armazenamento screen's state: one load of the storage portrait,
/// the math pure. The quota belongs to the box, and setting it is the
/// zeladora's, from this screen.
@MainActor
@Observable
final class StorageModel {
    /// One segment of the usage bar: a kind and its share of the used bytes.
    struct Segment: Equatable, Identifiable {
        let kind: StorageKind
        let fraction: Double
        var id: StorageKind { kind }
    }

    /// One row of the by-kind breakdown.
    struct KindLine: Equatable, Identifiable {
        let kind: StorageKind
        let bytes: Int64
        var id: StorageKind { kind }
    }

    private(set) var stats: StorageStats?
    private(set) var loading = false
    private(set) var error: TainaError?
    /// The quota the box is saving right now.
    private(set) var saving = false

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel) {
        self.api = api
        self.session = session
    }

    /// The acts belong to whoever cares for the box; the server enforces
    /// it again anyway.
    var isZelador: Bool {
        if case .ready(let me) = session.state {
            return me.ava.papel == .zelador
        }
        return false
    }

    func load() async {
        loading = true
        let result = await api.storage()
        switch await session.screen(result) {
        case .success(let value):
            stats = value
            error = nil
        case .failure(let failure):
            error = failure
        }
        loading = false
    }

    /// The zeladora's new limit, in bytes. The answer is the Tekoa; the
    /// portrait is read again so every line agrees with the box.
    func setQuota(bytes: Int64) async -> TainaResult<Void> {
        saving = true
        defer { saving = false }
        let result = await session.screen(await api.setQuota(bytes: bytes))
        switch result {
        case .success:
            await load()
            return .success(())
        case .failure(let failure):
            return .failure(failure)
        }
    }

    // MARK: pure transitions

    /// The by-kind rows, widest first, the order the web shows.
    static func kinds(_ stats: StorageStats) -> [KindLine] {
        [
            KindLine(kind: .photos, bytes: stats.byKind.photos),
            KindLine(kind: .videos, bytes: stats.byKind.videos),
            KindLine(kind: .documents, bytes: stats.byKind.documents),
            KindLine(kind: .others, bytes: stats.byKind.others),
        ]
        .sorted { $0.bytes > $1.bytes }
    }

    /// The bar's segments: only the kinds holding bytes, each as a share of
    /// the used total. Nothing used, no segments, just the track.
    static func segments(_ stats: StorageStats) -> [Segment] {
        guard stats.usedBytes > 0 else { return [] }
        let all: [(StorageKind, Int64)] = [
            (.photos, stats.byKind.photos),
            (.videos, stats.byKind.videos),
            (.documents, stats.byKind.documents),
            (.others, stats.byKind.others),
        ]
        return all
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { Segment(kind: $0.0, fraction: Double($0.1) / Double(stats.usedBytes)) }
    }

    /// What the by-kind list adds up to: the part of the vault this person
    /// can see, not the box's whole usage.
    static func byKindTotal(_ stats: StorageStats) -> Int64 {
        stats.byKind.photos + stats.byKind.videos + stats.byKind.documents + stats.byKind.others
    }

    /// True when the free room is at most a tenth of the quota, the web's
    /// threshold for the amber "livres". Without a quota, never.
    static func isLowFree(_ stats: StorageStats) -> Bool {
        guard let quota = stats.quotaBytes, quota > 0 else { return false }
        return Double(quota - stats.usedBytes) / Double(quota) <= 0.1
    }

    /// True when what is already kept is past the quota: the free room
    /// went negative, and "X livres" would be a lie. Setting a limit
    /// below the use is allowed on the box, on purpose.
    static func isOverQuota(_ stats: StorageStats) -> Bool {
        guard let quota = stats.quotaBytes else { return false }
        return stats.usedBytes > quota
    }

    /// The quota in whole gigabytes, rounded up, for the field that edits
    /// it. Without a quota, the field opens at the web's default.
    static func gigabytes(_ bytes: Int64?) -> Int64 {
        guard let bytes, bytes > 0 else { return 250 }
        let gib = Int64(1_073_741_824)
        return (bytes + gib - 1) / gib
    }

    /// The bytes of a whole number of gigabytes, the way the wire wants.
    static func bytes(fromGigabytes gigabytes: Int64) -> Int64 {
        gigabytes * 1_073_741_824
    }

    /// The trash row's value: "1 arquivo, 2,4 MB".
    static func trashSummary(_ trash: StorageStats.Trash) -> String {
        let files = trash.count == 1 ? "1 arquivo" : "\(trash.count) arquivos"
        return "\(files), \(Format.bytes(trash.bytes))"
    }
}
