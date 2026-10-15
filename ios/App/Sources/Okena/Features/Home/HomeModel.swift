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

    /// The chain stores the actor's public_id; the screen is who translates
    /// it to people, from the roster of the community.
    static func actorNames(from avas: [Ava]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: avas.map { ($0.publicId, $0.label) })
    }

    /// The teaser rows, newest first, each a ready sentence.
    static func lines(from entries: [MuralEntry], names: [String: String]) -> [MuralLine] {
        entries.map { entry in
            MuralLine(
                id: entry.cid,
                sentence: sentence(for: entry, names: names),
                ago: Format.relative(entry.createdAt)
            )
        }
    }

    /// The mural sentences: each `tipo` becomes one plain phrase, no ids
    /// and no jargon, the web's own table (`mural_live`). The mural is
    /// append-only and cannot fall over a missing phrase: an unknown type
    /// keeps the row on the air with the generic sentence.
    static func sentence(for entry: MuralEntry, names: [String: String]) -> String {
        let actor = actorLabel(for: entry, names: names)
        let role = string("role", in: entry.payload)
        let member = string("member", in: entry.payload)
        let folder = string("collection", in: entry.payload) == "ypy.folder.v0"
        switch entry.tipo {
        case "invite_created":
            return role == "zelador"
                ? "\(actor) convidou uma nova pessoa para cuidar da máquina."
                : "\(actor) convidou uma nova pessoa para a comunidade."
        case "invite_accepted":
            return role == "zelador"
                ? "\(actor) entrou na comunidade para cuidar da máquina."
                : "\(actor) entrou na comunidade."
        case "invite_revoked":
            return role == "zelador"
                ? "\(actor) revogou um convite para cuidar da máquina."
                : "\(actor) revogou um convite."
        case "reset_link_created":
            return member.map { "\(actor) gerou um link de nova senha para \($0)." }
                ?? "\(actor) gerou um link de nova senha para um membro da comunidade."
        case "member_deactivated":
            return member.map { "\(actor) desativou a conta de \($0)." }
                ?? "\(actor) desativou uma conta."
        case "member_reactivated":
            return member.map { "\(actor) reativou a conta de \($0)." }
                ?? "\(actor) reativou uma conta."
        case "quota_changed":
            let to = int("to", in: entry.payload)
            if let from = int("from", in: entry.payload), let to {
                return "\(actor) mudou o limite de armazenamento de \(Format.bytes(from)) para \(Format.bytes(to))."
            }
            if let to {
                return "\(actor) mudou o limite de armazenamento para \(Format.bytes(to))."
            }
            return "\(actor) mudou o limite de armazenamento."
        case "put":
            return folder ? "\(actor) criou uma pasta." : "\(actor) guardou um arquivo na caixa."
        case "publicar":
            return folder ? "\(actor) publicou uma pasta na praça." : "\(actor) publicou um arquivo na praça."
        case "tirar_da_praca":
            return folder ? "\(actor) tirou uma pasta da praça." : "\(actor) tirou um arquivo da praça."
        case "apagar":
            return folder ? "\(actor) mandou uma pasta para a lixeira." : "\(actor) mandou um arquivo para a lixeira."
        case "restaurar":
            return "\(actor) tirou um arquivo da lixeira."
        case "mover":
            return "\(actor) moveu um arquivo de pasta."
        case "renomear":
            return folder ? "\(actor) renomeou uma pasta." : "\(actor) renomeou um arquivo."
        case "concessao":
            return "\(actor) abriu a sua casa para a leitura de um morador."
        case "revogar":
            return "\(actor) tirou a leitura que tinha aberto."
        case "mudar_papel":
            return role == "zelador"
                ? "\(actor) deu a um morador o cuidado da máquina."
                : "\(actor) tirou de um morador o cuidado da máquina."
        default:
            return "\(actor) fez um ato registrado na comunidade."
        }
    }

    /// The actor's label, resolved from the roster. Without an actor, or
    /// with one the roster no longer knows, "O sistema" speaks, like the
    /// web does.
    static func actorLabel(for entry: MuralEntry, names: [String: String]) -> String {
        guard let pid = string("actor", in: entry.payload), let name = names[pid] else {
            return "O sistema"
        }
        return name
    }

    private static func string(_ key: String, in payload: [String: JSONValue]) -> String? {
        guard let raw = payload[key], case .string(let value) = raw else { return nil }
        return value
    }

    private static func int(_ key: String, in payload: [String: JSONValue]) -> Int64? {
        guard let raw = payload[key], case .int(let value) = raw else { return nil }
        return value
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
            names = Self.actorNames(from: page.items)
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
