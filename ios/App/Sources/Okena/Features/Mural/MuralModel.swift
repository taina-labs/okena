import OkenaCore
import SwiftUI

/// The mural's state: the community's ledger, newest first, read-only for
/// every papel, one page at a time. The phrases are pure functions here,
/// so a screen never reimplements the mural's words.
@MainActor
@Observable
final class MuralModel {
    private(set) var entries: [MuralEntry] = []
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

    // MARK: pure transitions

    /// The payload keys the summary renders, in the order the line shows
    /// them; the quota pair (from, to) is its own phrase.
    private static let summaryKeys = ["name", "file", "member", "zona", "size", "from", "to", "role", "papel", "motivo", "tags"]

    /// The chain's bookkeeping: ids and pointers that mean nothing to a
    /// person reading the mural, the same split the web's sentences make.
    private static let auditKeys: Set<String> = ["actor", "reader", "leitor", "rkey", "recurso", "cid", "prev", "public_id", "token", "collection"]

    /// The mural's word for the act, in pt-BR. The chain's own word for a
    /// folder or a file decides the noun, like the web's sentences do. A
    /// type the screen does not know yet falls back to the generic label:
    /// the mural is append-only and a missing phrase must never break a
    /// row. Pure.
    static func label(for entry: MuralEntry) -> String {
        let folder = entry.payload["collection"] == .string("ypy.folder.v0")
        return switch entry.tipo {
        case "invite_created": "Convite criado"
        case "invite_accepted": "Convite aceito"
        case "invite_revoked": "Convite revogado"
        case "reset_link_created": "Link de nova senha gerado"
        case "member_deactivated": "Conta desativada"
        case "member_reactivated": "Conta reativada"
        case "quota_changed": "Limite de armazenamento alterado"
        case "put": folder ? "Pasta criada" : "Arquivo guardado"
        case "publicar": "Publicado na praça"
        case "tirar_da_praca": "Tirado da praça"
        case "apagar": "Mandado para a lixeira"
        case "restaurar": "Restaurado da lixeira"
        case "mover": "Movido de pasta"
        case "renomear": folder ? "Pasta renomeada" : "Arquivo renomeado"
        case "concessao": "Leitura concedida"
        case "revogar": "Leitura revogada"
        case "mudar_papel": "Papel mudado"
        // The preview fake's own dotted words for the same acts.
        case "arquivo.criado": "Arquivo guardado"
        case "arquivo.publicado": "Publicado na praça"
        case "pasta.criada": "Pasta criada"
        case "pedido.aprovado": "Pedido aprovado"
        default: "Ato registrado"
        }
    }

    /// One short pt-BR line out of the payload: the fields a person reads,
    /// in order, the audit keys out, and a field the screen does not know
    /// yet still getting a readable "key: value". Never raw JSON. Pure.
    static func summary(from payload: [String: JSONValue]) -> String {
        var parts: [String] = []

        if let from = payload["from"], let to = payload["to"], from != .null, to != .null {
            parts.append("\(readable(key: "from", value: from)) para \(readable(key: "to", value: to))")
        } else {
            if let from = payload["from"], from != .null {
                parts.append("de \(readable(key: "from", value: from))")
            }
            if let to = payload["to"], to != .null {
                parts.append("para \(readable(key: "to", value: to))")
            }
        }

        for key in summaryKeys where key != "from" && key != "to" {
            guard let value = payload[key], value != .null else { continue }
            parts.append(readable(key: key, value: value))
        }

        for key in payload.keys.sorted() where !summaryKeys.contains(key) && !auditKeys.contains(key) {
            guard let value = payload[key], value != .null else { continue }
            parts.append("\(key): \(phrase(from: value))")
        }

        return parts.joined(separator: ", ")
    }

    /// One pt-BR phrase out of any JSON value: strings pass, flags become
    /// words, lists join, objects pair up. Pure.
    static func phrase(from value: JSONValue) -> String {
        switch value {
        case .null: ""
        case .bool(let flag): flag ? "sim" : "não"
        case .int(let number): String(number)
        case .double(let number): String(format: "%.1f", number).replacingOccurrences(of: ".", with: ",")
        case .string(let text): text
        case .array(let values): values.map { phrase(from: $0) }.filter { !$0.isEmpty }.joined(separator: ", ")
        case .object(let fields):
            fields.sorted(by: { $0.key < $1.key }).map { "\($0.key): \(phrase(from: $0.value))" }.joined(separator: ", ")
        }
    }

    /// One field, in the words of the screen: bytes as sizes, the zone and
    /// the role as the product's own words.
    private static func readable(key: String, value: JSONValue) -> String {
        switch key {
        case "from", "to", "size":
            if case .int(let bytes) = value { return Format.bytes(bytes) }
            return phrase(from: value)
        case "zona":
            return value == .string("praca") ? "Praça" : "Casa"
        case "role", "papel":
            return value == .string("zelador") ? "Zelador" : "Morador"
        default:
            return phrase(from: value)
        }
    }

    // MARK: internals

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
