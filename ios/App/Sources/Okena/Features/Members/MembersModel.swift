import OkenaCore
import SwiftUI

/// The members list's state: one load, the transitions pure. The screen is
/// read only: who is here, the role of each account, its state. Inviting,
/// changing roles and deactivating are acts of the zelador, and stay on the
/// web for now.
@MainActor
@Observable
final class MembersModel {
    private(set) var members: [Ava] = []
    private(set) var loading = false
    private(set) var error: TainaError?

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel) {
        self.api = api
        self.session = session
    }

    /// The person acting, when the session is ready: their own row reads
    /// "Você", like the web's list.
    var mePublicId: String? {
        if case .ready(let me) = session.state {
            return me.ava.publicId
        }
        return nil
    }

    func load() async {
        loading = true
        let result = await api.members()
        switch await session.screen(result) {
        case .success(let page):
            members = page.items
            error = nil
        case .failure(let failure):
            error = failure
        }
        loading = false
    }

    // MARK: pure transitions

    /// The count line above the list: "1 pessoa", "3 pessoas".
    static func countLine(_ count: Int) -> String {
        count == 1 ? "1 pessoa" : "\(count) pessoas"
    }

    /// The state line of a row, when there is one: a deactivated account
    /// wins, then the person acting. The role is a line of its own.
    static func meta(for member: Ava, mePublicId: String?) -> String? {
        if member.deactivatedAt != nil {
            return "Conta desativada"
        }
        if member.publicId == mePublicId {
            return "Você"
        }
        return nil
    }

    /// The avatar tint: a stable sum of the name's scalars, 0 to 3, so the
    /// same person lands on the same color.
    static func tintIndex(for name: String) -> Int {
        name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 4
    }
}
