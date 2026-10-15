import Foundation

/// The two zones of the social model. The word on the wire, in the model and
/// on the screen is the same.
public enum Zona: String, Codable, Sendable, CaseIterable {
    case casa, praca
}

/// The social role inside a Tekoa. "zelador" and "morador" are the words on
/// screen, never "admin" or "member".
public enum Papel: String, Codable, Sendable, CaseIterable {
    case zelador, morador
}

/// The person inside a Tekoa.
public struct Ava: Codable, Sendable, Equatable {
    public let publicId: String
    public let username: String?
    public let displayName: String?
    public let papel: Papel
    public let activatedAt: String?
    public let deactivatedAt: String?
    public let createdAt: String

    /// What a row shows: the display name when there is one, the username
    /// otherwise, and the invite's own words while the person has not
    /// chosen a name yet (the web's `display_name/1`). Pure, so the UI does
    /// not repeat the rule.
    public var label: String {
        displayName ?? username ?? "Convite pendente"
    }
}

/// The community. One per box.
public struct Tekoa: Codable, Sendable, Equatable {
    public let publicId: String
    public let name: String
    public let domain: String
    public let storageQuotaBytes: Int64?
    public let storageUsedBytes: Int64
    public let createdAt: String
}

/// The instance: whether the box is set up and which community it serves.
public struct Instance: Decodable, Sendable, Equatable {
    public let bootstrapped: Bool
    public let tekoa: Tekoa?
    public let version: String?
}

/// One authorized device, without the hash of the secret, ever.
public struct DeviceToken: Codable, Sendable, Equatable {
    public let publicId: String
    public let name: String
    public let lastUsedAt: String?
    public let revokedAt: String?
    public let createdAt: String
}

/// The file of the community, a record of the vault.
public struct File: Decodable, Sendable, Equatable {
    public let rkey: String
    public let cid: String
    public let blobCid: String
    public let sha256: String
    public let name: String
    public let mime: String
    public let size: Int64
    public let zona: Zona
    public let folder: String?
    public let deletedAt: String?
    public let createdAt: String
    public let updatedAt: String
}

/// The folder that organizes files, itself a record.
public struct Folder: Codable, Sendable, Equatable {
    public let rkey: String
    public let cid: String
    public let name: String
    public let zona: Zona
    public let folder: String?
    public let deletedAt: String?
    public let createdAt: String
    public let updatedAt: String
}
