import Foundation

/// The owner of a casa resource, for whoever does not read it yet: the
/// shape `GET /files/{id}/access-target` answers with.
public struct AccessTarget: Decodable, Sendable, Equatable {
    public let owner: Ava
    public let rkey: String
    public let name: String
}

/// Where an access request stands. The word on the wire, in the model and
/// on the screen is the same.
public enum PedidoStatus: String, Codable, Sendable, CaseIterable {
    case pendente, aprovado, negado
}

/// The access request. A mere intermediary: it grants nothing, it registers
/// the question, and the owner decides.
public struct Pedido: Decodable, Sendable, Equatable {
    public let publicId: String
    public let tipo: String
    public let recurso: String
    public let motivo: String?
    public let status: PedidoStatus
    public let decididoEm: String?
    public let createdAt: String
    public let pedinte: Ava?
    public let dono: Ava?
}

/// The explicit read permission. Revoking does not erase the fact.
public struct Concessao: Decodable, Sendable, Equatable {
    public let publicId: String
    public let tipo: String
    public let recurso: String
    public let concedidaEm: String?
    public let revogadaEm: String?
    public let createdAt: String
    public let leitor: Ava?
    public let dono: Ava?
}
