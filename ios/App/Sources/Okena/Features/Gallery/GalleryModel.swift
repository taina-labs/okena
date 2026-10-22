import OkenaCore
import SwiftUI

/// The Fotos screen's state: the grid and the timeline, each with its own
/// cursor, and the fullscreen viewer over whichever list is showing. The
/// loading logic lives here once; the decisions are the pure helpers below;
/// the view only assigns and calls (the web's gallery_live, minus the URL
/// routing).
@MainActor
@Observable
final class GalleryModel {
    enum Tab: CaseIterable, Hashable {
        case grid
        case timeline
    }

    /// The zone filter, the web's casa/praça row: the readable set already
    /// carries both zones, so narrowing is client-side only and the default
    /// shows everything.
    enum Filter: CaseIterable, Hashable {
        case all, praca, casa

        /// The zone the filter narrows to, nil for everything.
        var zona: Zona? {
            switch self {
            case .all: nil
            case .praca: .praca
            case .casa: .casa
            }
        }
    }

    /// One day of the timeline for display: a page may split a day in two,
    /// so the day shown is derived, fusing adjacent groups of the same
    /// date (the web's extend_timeline).
    struct Day: Equatable, Identifiable {
        let date: String
        let photos: [File]

        var id: String { date }
    }

    /// The fullscreen viewer: the photos it swipes through and where it is.
    struct Viewer: Equatable {
        let files: [File]
        var index: Int

        var file: File? {
            files.indices.contains(index) ? files[index] : nil
        }
    }

    /// The empty state's words, per what is empty: the readable set itself,
    /// or just the zone the filter is showing.
    struct EmptyCopy: Equatable {
        let systemImage: String
        let title: String
        let message: String
    }

    private(set) var tab = Tab.grid
    private(set) var filter = Filter.all
    private(set) var photos: [File] = []
    private(set) var days: [Day] = []
    private(set) var nextCursor: String?
    private(set) var timelineCursor: String?
    private(set) var loading = false
    private(set) var loadingMore = false
    private(set) var loaded = false
    private(set) var working = false
    private(set) var error: TainaError?
    private(set) var alertMessage: String?
    private(set) var viewer: Viewer?

    private var gridStale = true
    private var timelineStale = true

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel) {
        self.api = api
        self.session = session
    }

    /// Another page may come for the tab that is showing.
    var canLoadMore: Bool {
        switch tab {
        case .grid: nextCursor != nil
        case .timeline: timelineCursor != nil
        }
    }

    /// The footer sentinel's re-arm key: it changes when a page lands, so
    /// a footer still on screen keeps filling the list, and when the
    /// filter narrows it, so a short filtered list keeps loading too.
    var loadedCount: Int {
        switch tab {
        case .grid: filteredPhotos.count
        case .timeline: Self.photos(of: timelineDays).count
        }
    }

    /// The timeline as days, narrowed by the filter: the raw pages as they
    /// came, fused where a day straddles a page boundary, then the zones
    /// the filter does not show taken out, empty days with them.
    var timelineDays: [Day] {
        Self.filtering(days, by: filter)
    }

    /// The grid the filter shows.
    var filteredPhotos: [File] {
        Self.filtering(photos, by: filter)
    }

    private var visiblePhotos: [File] {
        switch tab {
        case .grid: filteredPhotos
        case .timeline: Self.photos(of: timelineDays)
        }
    }

    // MARK: transitions

    /// Entering a tab marks the one left stale, like the web: whichever
    /// list you leave refetches on the way back.
    func select(_ tab: Tab) {
        guard tab != self.tab else { return }
        switch tab {
        case .grid: timelineStale = true
        case .timeline: gridStale = true
        }
        self.tab = tab
    }

    /// Narrows the screen to a zone. Nothing refetches: both zones are
    /// already in memory (the web's for_zona).
    func select(_ filter: Filter) {
        guard filter != self.filter else { return }
        self.filter = filter
    }

    /// Loads the tab that is showing, once. The stale flag flips before
    /// the first await, so a second caller in the same pass waits for
    /// nothing.
    func ensureLoaded() async {
        switch tab {
        case .grid:
            guard gridStale else { return }
        case .timeline:
            guard timelineStale else { return }
        }
        await reload()
    }

    func refresh() async {
        guard !loading else { return }
        await reload()
    }

    func loadMore() async {
        guard !loadingMore else { return }
        switch tab {
        case .grid:
            guard let cursor = nextCursor else { return }
            loadingMore = true
            await appendGrid(await api.photos(limit: nil, cursor: cursor))
        case .timeline:
            guard let cursor = timelineCursor else { return }
            loadingMore = true
            await extendTimeline(await api.photoTimeline(limit: nil, cursor: cursor))
        }
        loadingMore = false
    }

    /// Opens the viewer over the list that is showing, at the photo tapped.
    func open(_ file: File) {
        let files = visiblePhotos
        viewer = Viewer(files: files, index: files.firstIndex(where: { $0.rkey == file.rkey }) ?? 0)
    }

    func close() {
        viewer = nil
    }

    /// The swipe landed on another photo.
    func moveViewer(to index: Int) {
        viewer?.index = index
    }

    func dismissAlert() {
        alertMessage = nil
    }

    // MARK: the viewer's acts

    /// Publishes to the praça, or takes back: the opposite of where the
    /// file is now, the same one-field update the file screen uses. The
    /// viewer closes on success, and the grid behind already shows the new
    /// badge, or no tile at all when the filter no longer shows the zone.
    func changeZone(of file: File) async {
        // The action always offers the opposite of where the file is now.
        let target: Zona = file.zona == .casa ? .praca : .casa
        working = true
        let result = await api.updateFile(rkey: file.rkey, name: nil, zona: target)
        switch await session.screen(result) {
        case .success(let updated):
            replace(updated)
            close()
        case .failure(let failure):
            alertMessage = Self.failureMessage(failure)
        }
        working = false
    }

    /// To the trash: the file leaves both lists, and the viewer with them.
    func delete(_ file: File) async {
        working = true
        let result = await api.deleteFile(rkey: file.rkey)
        switch await session.screen(result) {
        case .success:
            removePhoto(rkey: file.rkey)
            close()
        case .failure(let failure):
            alertMessage = Self.failureMessage(failure)
        }
        working = false
    }

    /// The download behind the viewer's share: the local file the share
    /// sheet hands to the system. A failure becomes the alert; the sheet
    /// on success is the view's.
    func download(_ file: File) async -> TainaResult<URL> {
        working = true
        let screened = await session.screen(await api.download(rkey: file.rkey))
        if case .failure(let failure) = screened {
            alertMessage = Self.failureMessage(failure)
        }
        working = false
        return screened
    }

    /// The video file for the viewer's playback. The page owns its own
    /// loading state, so the action row does not spin with it.
    func play(_ file: File) async -> TainaResult<URL> {
        await session.screen(await api.download(rkey: file.rkey))
    }

    // MARK: pure helpers

    static func isVideo(_ file: File) -> Bool {
        file.mime.hasPrefix("video/")
    }

    /// The label of a filter pill.
    static func label(of filter: Filter) -> String {
        switch filter {
        case .all: "Tudo"
        case .praca: "Praça"
        case .casa: "Casa"
        }
    }

    /// The files the filter shows: everything, or one zone's.
    static func filtering(_ files: [File], by filter: Filter) -> [File] {
        guard let zona = filter.zona else { return files }
        return files.filter { $0.zona == zona }
    }

    /// The days the filter shows: the zone's photos inside each day, the
    /// days that stay empty dropped.
    static func filtering(_ days: [Day], by filter: Filter) -> [Day] {
        days.compactMap { day in
            guard let zona = filter.zona else {
                return day.photos.isEmpty ? nil : day
            }
            let photos = day.photos.filter { $0.zona == zona }
            return photos.isEmpty ? nil : Day(date: day.date, photos: photos)
        }
    }

    /// The timeline as days: the raw page groups, fused where a day
    /// straddles a page boundary (the web's extend_timeline). A fresh page
    /// against empty days lays the first ones out.
    static func fusing(_ days: [Day], with groups: [TimelineGroup]) -> [Day] {
        var next = days
        for group in groups {
            if let last = next.last, last.date == group.date {
                next[next.count - 1] = Day(date: last.date, photos: last.photos + group.photos)
            } else {
                next.append(Day(date: group.date, photos: group.photos))
            }
        }
        return next
    }

    /// Every photo of the timeline in day order: the list the viewer
    /// swipes through.
    static func photos(of days: [Day]) -> [File] {
        days.flatMap(\.photos)
    }

    /// Where the photo sits in the list, 1-based, 1 when absent (the web's
    /// viewer_index).
    static func position(of file: File, in files: [File]) -> Int {
        (files.firstIndex(where: { $0.rkey == file.rkey }) ?? 0) + 1
    }

    static func replacing(_ file: File, in files: [File]) -> [File] {
        guard let at = files.firstIndex(where: { $0.rkey == file.rkey }) else { return files }
        var next = files
        next[at] = file
        return next
    }

    /// Puts the updated file back inside its day. The day stays even when
    /// its last photo is gone: a later page for the same date fuses onto
    /// it.
    static func replacing(_ file: File, in days: [Day]) -> [Day] {
        guard days.contains(where: { $0.photos.contains { $0.rkey == file.rkey } }) else {
            return days
        }
        return days.map { day in
            Day(date: day.date, photos: Self.replacing(file, in: day.photos))
        }
    }

    static func removing(rkey: String, from files: [File]) -> [File] {
        files.filter { $0.rkey != rkey }
    }

    /// The file out of its day, the day itself kept, for the same reason.
    static func removing(rkey: String, from days: [Day]) -> [Day] {
        days.map { day in
            Day(date: day.date, photos: Self.removing(rkey: rkey, from: day.photos))
        }
    }

    /// The type for a person, the web's human_type: the kind plus the
    /// subtype when it adds anything ("Vídeo MP4", "PDF").
    static func humanType(_ mime: String) -> String {
        let kind: String
        if mime.hasPrefix("image/") {
            kind = "Imagem"
        } else if mime.hasPrefix("video/") {
            kind = "Vídeo"
        } else if mime.hasPrefix("audio/") {
            kind = "Áudio"
        } else if mime == "application/pdf" {
            kind = "PDF"
        } else if mime == "application/zip" {
            kind = "ZIP"
        } else if mime.hasPrefix("text/") {
            kind = "Texto"
        } else {
            kind = "Arquivo"
        }
        let subtype = mime.split(separator: "/").last?.uppercased() ?? ""
        return subtype.isEmpty || kind == subtype ? kind : "\(kind) \(subtype)"
    }

    /// The zone in the details, in plain words.
    static func zoneSentence(_ zona: Zona) -> String {
        zona == .praca ? "Todos os moradores veem." : "Só você, e quem você deixar, vê."
    }

    /// The empty state's words: "nothing yet" when the readable set itself
    /// is empty, the zone's own when the filter narrowed everything away.
    static func emptyCopy(rawEmpty: Bool, filter: Filter) -> EmptyCopy {
        if rawEmpty || filter == .all {
            return noPhotos
        }
        switch filter.zona {
        case .casa:
            return EmptyCopy(
                systemImage: "photo",
                title: "Nada na sua casa ainda",
                message: "As fotos que você enviar aparecem aqui primeiro, só para você."
            )
        case .praca:
            return EmptyCopy(
                systemImage: "photo",
                title: "Nada na praça ainda",
                message: "As fotos publicadas na praça da comunidade aparecem aqui."
            )
        case .none:
            return noPhotos
        }
    }

    private static let noPhotos = EmptyCopy(
        systemImage: "photo",
        title: "Nenhuma foto ainda",
        message: "As imagens que a comunidade enviar aparecem aqui."
    )

    /// Grid density: 2 columns on the phone, 3 and 4 as the screen grows
    /// (the web steps 2/6/8/10 by breakpoint).
    static func columns(for width: CGFloat) -> Int {
        switch width {
        case ..<500: 2
        case ..<900: 3
        default: 4
        }
    }

    /// "Hoje, 5 fotos": the day first, relative when it is today or
    /// yesterday, then the count.
    static func sectionTitle(for day: Day, relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        let count = day.photos.count
        return "\(dayTitle(day.date, relativeTo: now, calendar: calendar)), \(count) \(count == 1 ? "foto" : "fotos")"
    }

    /// "Hoje" / "Ontem" / "21/06/2026". The wire date is day only, which
    /// `Format.date` cannot parse, so the day is read here, as UTC: the
    /// day is the one the box named, not the viewer's zone.
    static func dayTitle(_ date: String, relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        guard let day = parseDay(date) else {
            return date
        }
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: day), to: calendar.startOfDay(for: now)).day ?? 0
        switch elapsed {
        case 0:
            return "Hoje"
        case 1:
            return "Ontem"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: day)
        }
    }

    /// The upload day for the viewer header: the file's own clock, day
    /// only (the timeline groups by the effective date, the header does
    /// not).
    static func uploadedDay(_ iso: String) -> String {
        guard let parsed = parseTimestamp(iso) else {
            return iso
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: parsed)
    }

    /// The load-more failure, the web's flash sentence.
    static let loadMoreMessage = "Não foi possível carregar mais fotos agora."

    /// The act failure's sentence: the box's own pt-BR when it spoke, the
    /// generic otherwise.
    static func failureMessage(_ failure: TainaError) -> String {
        failure.errorDescription ?? "Algo deu errado. Tente de novo."
    }

    // MARK: internals

    private func replace(_ file: File) {
        photos = Self.replacing(file, in: photos)
        days = Self.replacing(file, in: days)
    }

    private func removePhoto(rkey: String) {
        photos = Self.removing(rkey: rkey, from: photos)
        days = Self.removing(rkey: rkey, from: days)
    }

    private func reload() async {
        loading = true
        error = nil
        switch tab {
        case .grid:
            gridStale = false
            let result = await api.photos(limit: nil, cursor: nil)
            switch await session.screen(result) {
            case .success(let page):
                photos = page.items
                nextCursor = page.nextCursor
            case .failure(let failure):
                error = failure
            }
        case .timeline:
            timelineStale = false
            let result = await api.photoTimeline(limit: nil, cursor: nil)
            switch await session.screen(result) {
            case .success(let page):
                days = Self.fusing([], with: page.items)
                timelineCursor = page.nextCursor
            case .failure(let failure):
                error = failure
            }
        }
        loading = false
        loaded = true
    }

    private func appendGrid(_ result: TainaResult<Page<File>>) async {
        switch await session.screen(result) {
        case .success(let page):
            photos = photos + page.items
            nextCursor = page.nextCursor
        case .failure:
            alertMessage = Self.loadMoreMessage
        }
    }

    private func extendTimeline(_ result: TainaResult<Page<TimelineGroup>>) async {
        switch await session.screen(result) {
        case .success(let page):
            days = Self.fusing(days, with: page.items)
            timelineCursor = page.nextCursor
        case .failure:
            alertMessage = Self.loadMoreMessage
        }
    }

    // ISO 8601 with an offset; fractional seconds happen. Formatters live
    // locally, not as globals: they are not Sendable.
    private static func parseTimestamp(_ iso: String) -> Date? {
        let whole = ISO8601DateFormatter()
        if let date = whole.date(from: iso) {
            return date
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: iso)
    }

    private static func parseDay(_ date: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}
