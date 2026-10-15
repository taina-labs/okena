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

    private(set) var tab = Tab.grid
    private(set) var photos: [File] = []
    private(set) var groups: [TimelineGroup] = []
    private(set) var nextCursor: String?
    private(set) var timelineCursor: String?
    private(set) var loading = false
    private(set) var loadingMore = false
    private(set) var loaded = false
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
    /// a footer still on screen keeps filling the list.
    var loadedCount: Int {
        switch tab {
        case .grid: photos.count
        case .timeline: Self.photos(of: groups).count
        }
    }

    /// The timeline as days: the raw pages as they came, fused where a day
    /// straddles a page boundary.
    var timelineDays: [Day] {
        Self.displayGroups(groups)
    }

    private var visiblePhotos: [File] {
        switch tab {
        case .grid: photos
        case .timeline: Self.photos(of: groups)
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

    // MARK: pure helpers

    static func isVideo(_ file: File) -> Bool {
        file.mime.hasPrefix("video/")
    }

    /// Grid density: 2 columns on the phone, 3 and 4 as the screen grows
    /// (the web steps 2/6/8/10 by breakpoint).
    static func columns(for width: CGFloat) -> Int {
        switch width {
        case ..<500: 2
        case ..<900: 3
        default: 4
        }
    }

    /// Every photo of the timeline in day order: the list the viewer
    /// swipes through.
    static func photos(of groups: [TimelineGroup]) -> [File] {
        groups.flatMap(\.photos)
    }

    /// Where the photo sits in the list, 1-based, 1 when absent (the web's
    /// viewer_index).
    static func position(of file: File, in files: [File]) -> Int {
        (files.firstIndex(where: { $0.rkey == file.rkey }) ?? 0) + 1
    }

    static func displayGroups(_ groups: [TimelineGroup]) -> [Day] {
        var days: [Day] = []
        for group in groups {
            if let last = days.last, last.date == group.date {
                days[days.count - 1] = Day(date: last.date, photos: last.photos + group.photos)
            } else {
                days.append(Day(date: group.date, photos: group.photos))
            }
        }
        return days
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

    // MARK: internals

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
                groups = page.items
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
            groups = groups + page.items
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
