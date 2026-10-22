import OkenaCore
import SwiftUI

/// The lixeira's state: what the community discarded, one page at a time,
/// with restore. The loading logic lives here once, and the trash rules
/// (retention, warning, meta line) are pure functions the views never
/// reimplement.
@MainActor
@Observable
final class TrashModel {
    private(set) var items: [File] = []
    private(set) var nextCursor: String?
    private(set) var loading = false
    private(set) var loadingMore = false
    private(set) var moreError = false
    private(set) var error: TainaError?
    /// The row being restored, so only its button spins.
    private(set) var restoringRkey: String?

    /// The same number the purge worker counts: 30 days, then the file is
    /// gone for good.
    static let retentionDays = 30
    /// At or below this many days left, the meta line turns to warning.
    static let warningDays = 5

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel) {
        self.api = api
        self.session = session
    }

    func load() async {
        loading = true
        let result = await api.trash(limit: nil, cursor: nil)
        await apply(result)
        loading = false
    }

    func loadMore() async {
        guard !loading, !loadingMore, let cursor = nextCursor else { return }
        loadingMore = true
        let result = await api.trash(limit: nil, cursor: cursor)
        await applyMore(result)
        loadingMore = false
    }

    /// Restores one file and drops the row on success; the failure goes
    /// back for the alert.
    func restore(rkey: String) async -> TainaResult<Void> {
        restoringRkey = rkey
        defer { restoringRkey = nil }
        let result = await api.restoreFile(rkey: rkey)
        switch await session.screen(result) {
        case .success:
            items = items.filter { $0.rkey != rkey }
            return .success(())
        case .failure(let failure):
            return .failure(failure)
        }
    }

    // MARK: pure transitions

    /// "%{count} item carregado(s)" while a page is still missing, the
    /// plain count at the end of the list.
    static func countLabel(count: Int, hasMore: Bool) -> String {
        let noun = count == 1 ? "1 item" : "\(count) itens"
        guard hasMore else { return noun }
        return noun + (count == 1 ? " carregado" : " carregados")
    }

    /// The SF Symbol for a mime, like the web's `file_visual/1`: the trash
    /// row shows a glyph, never a thumbnail of a discarded file.
    static func glyph(for mime: String) -> String {
        if mime.hasPrefix("image/") { return "photo" }
        if mime.hasPrefix("video/") { return "film" }
        if mime.hasPrefix("audio/") { return "waveform" }
        if mime == "application/pdf" { return "doc.richtext" }
        if mime.hasPrefix("text/") { return "doc.plaintext" }
        return "document"
    }

    /// The row's meta line, like the web's `trash_meta/1`: deleted when,
    /// days left before the purge, and who reads the file. Inside the
    /// warning window the line says the purge is close. Pure.
    static func meta(for file: File, now: Date = Date()) -> String {
        let zone = file.zona == .praca ? "Todos veem" : "Só você"
        guard let days = deletedDaysAgo(deletedAt: file.deletedAt ?? "", now: now) else {
            return "Apagado em \(Format.date(file.deletedAt ?? "")) / \(zone)"
        }
        let left = max(retentionDays - days, 0)
        if left == 0 {
            return "Apaga hoje / \(zone)"
        }
        if left <= warningDays {
            return left == 1
                ? "Resta 1 dia, apaga em breve / \(zone)"
                : "Restam \(left) dias, apaga em breve / \(zone)"
        }
        let deleted: String
        switch days {
        case 0: deleted = "Apagado hoje"
        case 1: deleted = "Apagado ontem"
        default: deleted = "Apagado há \(days) dias"
        }
        return deleted + (left == 1 ? ", resta 1 dia" : ", restam \(left) dias") + " / \(zone)"
    }

    /// True inside the warning window: few days left, the purge is close.
    static func isWarning(_ file: File, now: Date = Date()) -> Bool {
        guard let days = deletedDaysAgo(deletedAt: file.deletedAt ?? "", now: now) else {
            return false
        }
        return max(retentionDays - days, 0) <= warningDays
    }

    /// Whole days since the deletion, never negative: a clock ahead of the
    /// box's must not read "apagado há -1 dias".
    private static func deletedDaysAgo(deletedAt: String, now: Date) -> Int? {
        guard let deleted = parse(deletedAt) else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: deleted), to: calendar.startOfDay(for: now)).day ?? 0
        return max(days, 0)
    }

    // The server sends ISO 8601 with an offset; fractional seconds happen.
    // Formatters live locally: they are not Sendable.
    private static func parse(_ iso: String) -> Date? {
        let whole = ISO8601DateFormatter()
        if let date = whole.date(from: iso) {
            return date
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: iso)
    }

    // MARK: internals

    private func apply(_ result: TainaResult<Page<File>>) async {
        switch await session.screen(result) {
        case .success(let page):
            items = page.items
            nextCursor = page.nextCursor
            moreError = false
            error = nil
        case .failure(let failure):
            error = failure
        }
    }

    private func applyMore(_ result: TainaResult<Page<File>>) async {
        switch await session.screen(result) {
        case .success(let page):
            items += page.items
            nextCursor = page.nextCursor
            moreError = false
        case .failure:
            // A page that fails leaves the list as it is and the cursor
            // alive: the sentinel offers the retry.
            moreError = true
        }
    }
}
