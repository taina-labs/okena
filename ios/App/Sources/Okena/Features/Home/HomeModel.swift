import OkenaCore
import SwiftUI

/// The home's state, the mirror of the web's `home_live`: the recent
/// uploads, the storage card, a mural teaser and the count of pending
/// access requests. The home degrades instead of falling: every section
/// carries its own error, so one failing call never blanks the screen.
@MainActor
@Observable
final class HomeModel {
    /// One teaser row: the sentence the entry becomes and when it happened.
    struct MuralLine: Equatable, Identifiable {
        let id: String
        let sentence: String
        let ago: String
    }

    private(set) var loaded = false
    private(set) var recent: [File] = []
    private(set) var recentError: TainaError?
    private(set) var stats: StorageStats?
    private(set) var statsError = false
    private(set) var mural: [MuralLine] = []
    private(set) var muralError = false
    private(set) var pendingRequests: Int?
    private(set) var requestsError = false

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel) {
        self.api = api
        self.session = session
    }

    func load() async {
        await loadMural()
        await loadRecent()
        await loadStorage()
        await loadRequests()
        loaded = true
    }

    /// The storage card's own way back, like the web's `retry-storage`:
    /// only the stats, never the whole screen.
    func retryStorage() async {
        await loadStorage()
    }

    // MARK: pure transitions

    /// The greeting by the clock of the device: the phone is where the
    /// person is, so its hour is the hour that greets them.
    static func greeting(hour: Int) -> String {
        switch hour {
        case 5...11: "Bom dia,"
        case 12...17: "Boa tarde,"
        default: "Boa noite,"
        }
    }

    /// A quota defined and above zero: without one there is no free space
    /// to measure, and the card shows only the use.
    static func hasQuota(_ stats: StorageStats) -> Bool {
        guard let quota = stats.quotaBytes else { return false }
        return quota > 0
    }

    /// How much of the community's space is in use, 0...100.
    static func storagePercent(_ stats: StorageStats) -> Int {
        guard let quota = stats.quotaBytes, quota > 0 else { return 0 }
        let fraction = Double(stats.usedBytes) / Double(quota)
        return min(100, max(0, Int((fraction * 100).rounded())))
    }

    /// Nearly full: 90% of the quota or more. Words and an icon carry the
    /// warning, never the color alone.
    static func storageLow(_ stats: StorageStats) -> Bool {
        hasQuota(stats) && storagePercent(stats) >= 90
    }

    static func freeLabel(_ stats: StorageStats) -> String {
        guard let quota = stats.quotaBytes, quota > 0 else { return "" }
        let free = Format.bytes(quota - stats.usedBytes)
        return storageLow(stats) ? "quase cheia: \(free) livres" : "\(free) livres"
    }

    /// The meta of a recent row ends in the zone, in words (never color
    /// alone): "Imagem, 2,4 MB, ontem, na praça".
    static func recentMeta(_ file: File) -> String {
        [
            fileKind(file.mime),
            Format.bytes(file.size),
            Format.relative(file.createdAt),
            zonaWord(file.zona),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    static func zonaWord(_ zona: Zona) -> String {
        zona == .praca ? "na praça" : "na casa"
    }

    /// The short kind word for a row ("PDF", "Imagem"...), the web's own
    /// `file_kind`.
    static func fileKind(_ mime: String) -> String {
        if mime.hasPrefix("image/") { return "Imagem" }
        if mime.hasPrefix("video/") { return "Vídeo" }
        if mime.hasPrefix("audio/") { return "Áudio" }
        if mime == "application/pdf" { return "PDF" }
        if mime == "application/zip" { return "ZIP" }
        if mime.hasPrefix("text/") { return "Texto" }
        return "Arquivo"
    }

    static func pendingLabel(_ count: Int) -> String {
        switch count {
        case 0: "Nenhum pedido esperando"
        case 1: "1 pedido esperando"
        default: "\(count) pedidos esperando"
        }
    }

    /// The pending ones are the only count worth a card: a decided pedido
    /// registers a fact, it does not ask for anything.
    static func pendingCount(from page: Page<Pedido>) -> Int {
        page.items.filter { $0.status == .pendente }.count
    }

    /// The teaser rows, newest first, each a ready sentence, from the one
    /// shared table of mural phrases (`MuralPhrase`).
    static func lines(from entries: [MuralEntry], names: [String: String]) -> [MuralLine] {
        entries.map { entry in
            MuralLine(
                id: entry.cid,
                sentence: MuralPhrase.sentence(for: entry, names: names),
                ago: Format.relative(entry.createdAt)
            )
        }
    }

    // MARK: internals

    private func loadRecent() async {
        let result = await api.recent(limit: 4)
        switch await session.screen(result) {
        case .success(let page):
            recent = page.items
            recentError = nil
        case .failure(let error):
            recent = []
            recentError = error
        }
    }

    private func loadStorage() async {
        let result = await api.storage()
        switch await session.screen(result) {
        case .success(let loaded):
            stats = loaded
            statsError = false
        case .failure:
            stats = nil
            statsError = true
        }
    }

    private func loadMural() async {
        var names: [String: String] = [:]
        let roster = await api.members()
        if case .success(let page) = await session.screen(roster) {
            names = MuralPhrase.actorNames(from: page.items)
        }
        let result = await api.mural(limit: 3, cursor: nil)
        switch await session.screen(result) {
        case .success(let page):
            mural = Self.lines(from: page.items, names: names)
            muralError = false
        case .failure:
            mural = []
            muralError = true
        }
    }

    private func loadRequests() async {
        let result = await api.accessRequests()
        switch await session.screen(result) {
        case .success(let page):
            pendingRequests = Self.pendingCount(from: page)
            requestsError = false
        case .failure:
            pendingRequests = nil
            requestsError = true
        }
    }
}
