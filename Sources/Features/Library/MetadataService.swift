import Foundation
import Common
import Networking

public struct MetadataConfiguration: Sendable {
    public var preferredProvider: Provider
    public var cacheDirectory: URL

    public init(preferredProvider: Provider = .tmdb, cacheDirectory: URL = Self.defaultCacheDirectory()) {
        self.preferredProvider = preferredProvider
        self.cacheDirectory = cacheDirectory
    }

    public static func defaultCacheDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("MetadataImages", isDirectory: true)
    }

    public enum Provider: Sendable {
        case tmdb
        case tvdb
    }
}

public protocol MetadataServiceProtocol {
    func enrich(items: [MediaItem]) async -> [MediaItem]
}

public final class MetadataService: MetadataServiceProtocol {
    private let network: NetworkClientProtocol
    private let config: MetadataConfiguration

    public init(network: NetworkClientProtocol = NetworkClient(), config: MetadataConfiguration = MetadataConfiguration()) {
        self.network = network
        self.config = config
        try? FileManager.default.createDirectory(at: config.cacheDirectory, withIntermediateDirectories: true)
    }

    public func enrich(items: [MediaItem]) async -> [MediaItem] {
        // Placeholder enrichment: attach cached artwork if present
        return items.map { item in
            var copy = item
            let fileName = item.title.replacingOccurrences(of: " ", with: "_") + ".jpg"
            let cached = config.cacheDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: cached.path) {
                copy.artworkURL = cached
            }
            return copy
        }
    }
}
