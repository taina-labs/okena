import OkenaCore
import SwiftUI

/// The pedidos screen's state: what the community asked of this person and
/// what this person asked of others, plus the decisions on the received
/// ones. Both wire lists hold the pending ones only, so deciding is
/// removing; the loading logic lives here once and the transitions are pure
/// functions the views never reimplement.
@MainActor
@Observable
final class RequestsModel {
    struct Sections: Equatable {
        var received: [Pedido] = []
        var sent: [Pedido] = []
    }

    private(set) var sections = Sections()
    /// Resource rkey to display name, one map per list: the owner resolves
    /// the name on their own file record, the pedinte reads the access
    /// target, which carries the name without the file itself.
    private(set) var receivedNames: [String: String] = [:]
    private(set) var sentNames: [String: String] = [:]
    private(set) var loading = false
    private(set) var error: TainaError?
    /// The publicId of the pedido the box is deciding right now.
    private(set) var deciding: String?

    private let api: TainaAPI
    private let session: SessionModel

    init(api: TainaAPI, session: SessionModel) {
        self.api = api
        self.session = session
    }

    func load() async {
        loading = true
        let received = await session.screen(await api.accessRequests())
        let sent = await session.screen(await api.myRequests())
        await apply(received: received, sent: sent)
        loading = false
    }

    /// Grants the read: the concessao is born on the box and the pedido
    /// leaves the pending list. The screen says what the outcome was.
    func approve(id: String) async -> TainaResult<Void> {
        deciding = id
        defer { deciding = nil }
        let result = await session.screen(await api.approveRequest(id: id))
        return settle(result, id: id)
    }

    /// Denies the read: nothing opens, and the person may ask again later.
    func deny(id: String) async -> TainaResult<Void> {
        deciding = id
        defer { deciding = nil }
        let result = await session.screen(await api.denyRequest(id: id))
        return settle(result, id: id)
    }

    // MARK: pure transitions

    /// The neutral label for a resource the box no longer knows. Never an
    /// error screen: the pedido, and the decision about it, still stand.
    static let deletedResource = "arquivo apagado"

    static func resourceName(for pedido: Pedido, in names: [String: String]) -> String {
        names[pedido.recurso] ?? deletedResource
    }

    /// The row's title: the person the row is about, the pedinte on the
    /// received list and the dono on the sent one. The wire preloads both
    /// ends; a missing end still names a person of the community.
    static func personLabel(_ ava: Ava?) -> String {
        ava?.label ?? "Pessoa da comunidade"
    }

    /// The resource line, in the sentence the row speaks: the owner reads
    /// who asked, the pedinte reads who decides.
    static func resourceLine(received: Bool, name: String) -> String {
        received ? "Pediu acesso a \(name)" : "Pedido para abrir \(name)"
    }

    /// The overline of the received list: every row there waits on this
    /// person.
    static func receivedHeader(count: Int) -> String {
        count == 1 ? "1 pedido esperando sua resposta" : "\(count) pedidos esperando sua resposta"
    }

    /// The outcome named on the file, like the web's flash: a decision is
    /// about that file, not about "a pedido".
    static func approvedMessage(named name: String?) -> String {
        guard let name else { return "Acesso liberado. A pessoa já pode ler." }
        return "Acesso a \(name) liberado. A pessoa já pode ler."
    }

    /// Removing the decided pedido from both pending lists, by identity.
    static func removing(id: String, from sections: Sections) -> Sections {
        Sections(
            received: sections.received.filter { $0.publicId != id },
            sent: sections.sent.filter { $0.publicId != id }
        )
    }

    // MARK: internals

    private func apply(received: TainaResult<Page<Pedido>>, sent: TainaResult<Page<Pedido>>) async {
        switch (received, sent) {
        case let (.success(receivedPage), .success(sentPage)):
            sections = Sections(received: receivedPage.items, sent: sentPage.items)
            receivedNames = await names(for: receivedPage.items, asOwner: true)
            sentNames = await names(for: sentPage.items, asOwner: false)
            error = nil
        case (.failure(let failure), _), (_, .failure(let failure)):
            error = failure
        }
    }

    private func settle<Value>(_ result: TainaResult<Value>, id: String) -> TainaResult<Void> {
        switch result {
        case .success:
            sections = Self.removing(id: id, from: sections)
            return .success(())
        case .failure(let failure):
            return .failure(failure)
        }
    }

    /// One name per unique resource. A resource that is gone answers the
    /// neutral label, like the web; the pedido line stays legible.
    private func names(for pedidos: [Pedido], asOwner: Bool) async -> [String: String] {
        var names: [String: String] = [:]
        for pedido in pedidos where names[pedido.recurso] == nil {
            let found: TainaResult<String> = asOwner
                ? await session.screen(await api.file(rkey: pedido.recurso)).map(\.name)
                : await session.screen(await api.accessTarget(fileRkey: pedido.recurso)).map(\.name)
            if case .success(let name) = found {
                names[pedido.recurso] = name
            } else {
                names[pedido.recurso] = Self.deletedResource
            }
        }
        return names
    }
}
