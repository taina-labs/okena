import Foundation

/// How a list asks the server to order itself. One word on the wire, for
/// example `date_desc`.
public struct Sort: Equatable, Sendable {
    public enum Key: String, Sendable, CaseIterable { case name, date, size }
    public enum Direction: String, Sendable, CaseIterable { case asc, desc }

    public let key: Key
    public let direction: Direction

    public var wire: String {
        "\(key.rawValue)_\(direction.rawValue)"
    }

    public init(key: Key, direction: Direction = .asc) {
        self.key = key
        self.direction = direction
    }
}
