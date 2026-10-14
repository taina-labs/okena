import Foundation

/// A bounded in-memory thumbnail cache, keyed by rkey and size. A grid that
/// scrolls must not issue one request per row per pass over the screen.
/// Every thumbnail response is small and already webp, so bytes in memory
/// are the whole story: no disk cache yet, that becomes worth it when the
/// photo grid lands. A failure is not cached, so a transient miss retries
/// on the next pass.
public actor ThumbnailStore {
    private let api: TainaAPI
    private let cache: NSCache<NSString, NSData>

    public init(api: TainaAPI, countLimit: Int = 256) {
        self.api = api
        cache = NSCache()
        cache.countLimit = countLimit
    }

    /// Cached by rkey and size. A miss fetches once.
    public func data(rkey: String, size: ThumbnailSize) async -> TainaResult<Data> {
        let key = "\(rkey)-\(size.rawValue)" as NSString
        if let hit = cache.object(forKey: key) {
            return .success(hit as Data)
        }
        let fetched = await api.thumbnail(rkey: rkey, size: size)
        if case .success(let data) = fetched {
            cache.setObject(data as NSData, forKey: key)
        }
        return fetched
    }

    public func clear() {
        cache.removeAllObjects()
    }
}
