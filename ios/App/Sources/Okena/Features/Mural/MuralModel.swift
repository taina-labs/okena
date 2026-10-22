import OkenaCore
import SwiftUI

/// The mural's state: the community's ledger, newest first, read-only for
/// every papel, one page at a time. The sentences come from the one shared
/// table (`MuralPhrase`), so the screen and the Home teaser never drift.
@MainActor
@Observable
final class MuralModel {
    private(set) var entries: [MuralEntry] = []
    /// public_id -> social label, so the chain's actor ids read as people.
    private(set) var names: [String: String] = [:]
    private(set) var nextCursor: String?
    private(set) var loading = false
    private(set) var loadingMore = false
    private(set) var moreError = false
    private(set) var error: TainaError?

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel) {
        self.api = api
        self.session = session
    }

    func load() async {
        loading = true
        await loadNames()
        let result = await api.mural(limit: nil, cursor: nil)
        await apply(result)
        loading = false
    }

    func loadMore() async {
        guard !loading, !loadingMore, let cursor = nextCursor else { return }
        loadingMore = true
        let result = await api.mural(limit: nil, cursor: cursor)
        await applyMore(result)
        loadingMore = false
    }

    /// The sentence for one entry, from the shared table and the roster.
    func sentence(for entry: MuralEntry) -> String {
        MuralPhrase.sentence(for: entry, names: names)
    }

    // MARK: internals

    /// The roster that turns the chain's actor ids into names. Best effort:
    /// a mural that cannot resolve names still shows its sentences with
    /// "O sistema" speaking.
    private func loadNames() async {
        let roster = await api.members()
        if case .success(let page) = await session.screen(roster) {
            names = MuralPhrase.actorNames(from: page.items)
        }
    }

    private func apply(_ result: TainaResult<Page<MuralEntry>>) async {
        switch await session.screen(result) {
        case .success(let page):
            entries = page.items
            nextCursor = page.nextCursor
            moreError = false
            error = nil
        case .failure(let failure):
            error = failure
        }
    }

    private func applyMore(_ result: TainaResult<Page<MuralEntry>>) async {
        switch await session.screen(result) {
        case .success(let page):
            entries += page.items
            nextCursor = page.nextCursor
            moreError = false
        case .failure:
            // A page that fails leaves the list as it is and the cursor
            // alive: the sentinel offers the retry.
            moreError = true
        }
    }
}
