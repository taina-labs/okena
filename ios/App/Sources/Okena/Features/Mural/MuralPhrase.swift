import OkenaCore

/// The mural's words, in one place. Each chain `tipo` becomes one plain
/// pt-BR sentence, no ids and no jargon: the web's own table
/// (`mural_live.sentence/2`), shared by the Home teaser and the Mural
/// screen so the two never drift. The mural is append-only: a type the
/// screen does not know yet keeps its row on the air with the generic
/// sentence.
enum MuralPhrase {
    /// The chain stores the actor's public_id; the screen is who translates
    /// it to people, from the roster of the community.
    static func actorNames(from avas: [Ava]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: avas.map { ($0.publicId, $0.label) })
    }

    /// The sentence the entry becomes. Pure.
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
}
