import Foundation

/// The answer of the light token reads (`GET /invites/:token`,
/// `GET /password-resets/:token`): the screen opens with it and shows the
/// form, while the real validation stays on the POST.
public struct TokenStatus: Decodable, Sendable, Equatable {
    public let valid: Bool

    public init(valid: Bool) {
        self.valid = valid
    }
}
