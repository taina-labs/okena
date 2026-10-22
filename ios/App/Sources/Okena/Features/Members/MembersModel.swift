import OkenaCore
import SwiftUI

/// The members list's state: one load, the transitions pure. The acts of
/// the zeladora live here too: mint an invite and hand over its link,
/// change a role, switch an account off and on, take a pending invite
/// back, and mint a password link for one person.
@MainActor
@Observable
final class MembersModel {
    private(set) var members: [Ava] = []
    private(set) var loading = false
    private(set) var error: TainaError?
    /// The publicId of the person the box is acting on right now.
    private(set) var working: String?

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

    /// Mints the invite. The link travels by hand, so the screen shows it
    /// once for the copy; the new pending person joins the roster.
    func invite(papel: Papel) async -> TainaResult<MemberInvite> {
        let result = await session.screen(await api.inviteMember(papel: papel))
        if case .success(let created) = result {
            members = Self.inserting(created.ava, into: members)
        }
        return result
    }

    /// The role change, one person at a time. The row reads the answer.
    func changeRole(id: String, to papel: Papel) async -> TainaResult<Ava> {
        working = id
        defer { working = nil }
        let result = await session.screen(await api.updateMember(id: id, papel: papel))
        if case .success(let updated) = result {
            members = Self.replacing(id: id, with: updated, in: members)
        }
        return result
    }

    /// Deactivates: the account stops resolving, the fact stays listed.
    /// The answer is a 204 with no body, so the list is read again.
    func deactivate(id: String) async -> TainaResult<Void> {
        working = id
        defer { working = nil }
        let result = await session.screen(await api.deactivateMember(id: id))
        switch result {
        case .success:
            await load()
            return .success(())
        case .failure(let failure):
            return .failure(failure)
        }
    }

    /// Brings an account back; its old tokens count again.
    func reactivate(id: String) async -> TainaResult<Ava> {
        working = id
        defer { working = nil }
        let result = await session.screen(await api.reactivateMember(id: id))
        if case .success(let updated) = result {
            members = Self.replacing(id: id, with: updated, in: members)
        }
        return result
    }

    /// Takes a pending invite back: the person was never in, so the row
    /// leaves the list.
    func revokeInvite(id: String) async -> TainaResult<Void> {
        working = id
        defer { working = nil }
        let result = await session.screen(await api.revokeInvite(id: id))
        if case .success = result {
            members = Self.removing(id: id, from: members)
        }
        return result
    }

    /// Mints the password link of one person, shown once for the copy.
    func resetLink(id: String) async -> TainaResult<ResetLink> {
        await session.screen(await api.memberResetLink(id: id))
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

    /// A pending invite: the account exists only as the invitation, with
    /// no username and no activation yet.
    static func isPendingInvite(_ member: Ava) -> Bool {
        member.username == nil && member.activatedAt == nil
    }

    /// The avatar tint: a stable sum of the name's scalars, 0 to 3, so the
    /// same person lands on the same color.
    static func tintIndex(for name: String) -> Int {
        name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 4
    }

    /// The pending person joins the roster, zeladoras first, like the box
    /// orders the list. Pure.
    static func inserting(_ member: Ava, into members: [Ava]) -> [Ava] {
        (members + [member]).sorted { lhs, rhs in
            if lhs.papel != rhs.papel {
                return lhs.papel == .zelador
            }
            return lhs.label < rhs.label
        }
    }

    /// One row swapped for the answer. Pure.
    static func replacing(id: String, with updated: Ava, in members: [Ava]) -> [Ava] {
        members.map { member in
            member.publicId == id ? updated : member
        }
    }

    /// One row gone. Pure.
    static func removing(id: String, from members: [Ava]) -> [Ava] {
        members.filter { $0.publicId != id }
    }
}
