import Foundation

/// One day of the photo timeline: the effective date (EXIF when there is
/// one, otherwise the upload) with the photos taken inside it.
public struct TimelineGroup: Decodable, Sendable, Equatable {
    public let date: String
    public let photos: [File]
}
