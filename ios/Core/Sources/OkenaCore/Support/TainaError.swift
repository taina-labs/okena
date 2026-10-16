import Foundation

/// Every way a call can fail, as a value. Nothing throws across a boundary
/// that a caller does not own.
public enum TainaError: Error, Equatable, Sendable {
    case network(String)
    case invalidURL(String)
    case invalidResponse(String)
    case api(APIError)
    case invalidAddress(AddressProblem)
    case keychain(OSStatus)
    case notSignedIn
    case cancelled
}

/// The decoded error envelope, and the client's contract with it. `code`
/// stays a String on purpose: it is the wire vocabulary and the server owns
/// it, so a new atom must not break an old client. 403 `account_deactivated`
/// must stay distinguishable from 403 `forbidden`: the client must not
/// re-prompt for credentials in the first case.
public struct APIError: Error, Equatable, Sendable {
    public let code: String
    public let status: Int
    /// pt-BR, from the server, shown as-is.
    public let message: String
    /// Field to messages, empty when absent.
    public let details: [String: [String]]

    public var isUnauthorized: Bool { status == 401 }
    public var isForbidden: Bool { status == 403 }
    public var isNotFound: Bool { status == 404 }
    public var isConflict: Bool { status == 409 }
    public var isValidationFailed: Bool { code == "validation_failed" }
    public var isRateLimited: Bool { code == "rate_limited" }
    public var isQuotaExceeded: Bool { code == "storage_quota_exceeded" }
    public var isDeactivated: Bool { code == "account_deactivated" }

    /// Every field message, for a form that shows them as a list.
    public var fieldMessages: [String] {
        details.values.flatMap { $0 }
    }
}

/// The reason a typed address was refused.
public enum AddressProblem: String, Equatable, Sendable {
    case empty
    case malformed
    case unsupportedScheme

    /// One sentence, with a way out.
    public var message: String {
        switch self {
        case .empty: "Informe o endereço da comunidade, por exemplo taina.minhacasa.ts.net."
        case .malformed: "Este endereço não pôde ser lido. Use algo como taina.minhacasa.ts.net."
        case .unsupportedScheme: "Use o endereço da comunidade, por exemplo taina.minhacasa.ts.net."
        }
    }
}

extension TainaError: LocalizedError {
    /// pt-BR on purpose: there is no localization layer yet. For `.api` the
    /// server's message wins, in the tone it was written in.
    public var errorDescription: String? {
        switch self {
        case .network: "Não foi possível falar com a comunidade. Verifique a conexão e tente de novo."
        case .invalidURL: "O endereço da comunidade não pôde ser usado. Confira o que está salvo no aparelho."
        case .invalidResponse: "A comunidade respondeu algo inesperado. Tente de novo; se continuar, atualize o Tainá na caixa."
        case .api(let error): error.message
        case .invalidAddress(let problem): problem.message
        case .keychain: "Não foi possível guardar a sessão neste aparelho."
        case .notSignedIn: "Entre na sua conta para continuar."
        case .cancelled: "A operação foi cancelada."
        }
    }
}

extension TainaError {
    /// The envelope's messages for the first of `fields` that has any, in
    /// the wire spellings, so a form shows them under the right input. A
    /// local error (no envelope) carries none.
    public func messages(for fields: [String]) -> [String] {
        guard case .api(let error) = self else { return [] }
        for field in fields {
            if let messages = error.details[field], !messages.isEmpty {
                return messages
            }
        }
        return []
    }
}
