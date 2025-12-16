import Foundation
import Common
import Networking

public protocol MetadataServiceProtocol {
    func fetchMetadata(for item: MediaItem) async throws -> MediaItem
    func cacheStatus(for imageURL: URL?) -> MetadataCacheStatus
}

public enum MetadataProvider: String {
    case tmdb
    case tvdb
}

public enum MetadataError: LocalizedError {
    case unavailableProvider
    case retryExhausted(last: Error)
    case allProvidersFailed([Error])

    public var errorDescription: String? {
        switch self {
        case .unavailableProvider: return "未配置可用的元数据提供方"
        case .retryExhausted(let last): return "请求多次失败：\(last.localizedDescription)"
        case .allProvidersFailed(let errors):
            let combined = errors.map { $0.localizedDescription }.joined(separator: "; ")
            return combined.isEmpty ? "元数据提供方不可用" : "全部提供方失败：\(combined)"
        }
    }
}

public struct MetadataConfiguration {
    public var tmdbAPIKey: String?
    public var tvdbToken: String?
    public var preferredProvider: MetadataProvider
    public var maxRetries: Int
    public var baseBackoff: TimeInterval

    public init(tmdbAPIKey: String? = ProcessInfo.processInfo.environment["TMDB_API_KEY"],
                tvdbToken: String? = ProcessInfo.processInfo.environment["TVDB_TOKEN"],
                preferredProvider: MetadataProvider = .tmdb,
                maxRetries: Int = 2,
                baseBackoff: TimeInterval = 0.4) {
        self.tmdbAPIKey = tmdbAPIKey
        self.tvdbToken = tvdbToken
        self.preferredProvider = preferredProvider
        self.maxRetries = maxRetries
        self.baseBackoff = baseBackoff
    }
}

public final class MetadataService: MetadataServiceProtocol {
    private let client: NetworkClientProtocol
    private let configuration: MetadataConfiguration
    private let imageCache: MetadataImageCache

    public init(client: NetworkClientProtocol = NetworkClient(),
                configuration: MetadataConfiguration = .init(),
                imageCache: MetadataImageCache = MetadataImageCache()) {
        self.client = client
        self.configuration = configuration
        self.imageCache = imageCache
    }

    public func fetchMetadata(for item: MediaItem) async throws -> MediaItem {
        let providerOrder: [MetadataProvider] = configuration.preferredProvider == .tmdb ? [.tmdb, .tvdb] : [.tvdb, .tmdb]

        var errors: [Error] = []
        for provider in providerOrder {
            do {
                let enriched = try await performWithRetry(maxRetries: configuration.maxRetries, baseDelay: configuration.baseBackoff) {
                    try await self.fetchFromProvider(provider, for: item)
                }

                if let enriched { return enriched }
            } catch {
                errors.append(error)
                continue
            }
        }

        if errors.isEmpty {
            return item
        }

        throw MetadataError.allProvidersFailed(errors)
    }

    public func cacheStatus(for imageURL: URL?) -> MetadataCacheStatus {
        imageCache.status(for: imageURL)
    }

    private func fetchFromProvider(_ provider: MetadataProvider, for item: MediaItem) async throws -> MediaItem? {
        switch provider {
        case .tmdb:
            guard let apiKey = configuration.tmdbAPIKey else { return nil }
            return try await fetchFromTMDb(apiKey: apiKey, item: item)
        case .tvdb:
            guard let token = configuration.tvdbToken else { return nil }
            return try await fetchFromTVDb(token: token, item: item)
        }
    }

    // MARK: - TMDb

    private func fetchFromTMDb(apiKey: String, item: MediaItem) async throws -> MediaItem? {
        let query = item.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.title
        let typePath: String
        switch item.type {
        case .movie: typePath = "movie"
        case .tvShow: typePath = "tv"
        case .music: typePath = "multi"
        }
        let urlString = "https://api.themoviedb.org/3/search/\(typePath)?api_key=\(apiKey)&query=\(query)"
        guard let url = URL(string: urlString) else { return nil }

        let data = try await client.get(url: url, headers: [:])
        let response = try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
        guard let first = response.results.first else { return nil }

        var updated = item
        updated.originalTitle = first.originalTitle ?? updated.originalTitle
        updated.overview = first.overview ?? updated.overview
        updated.releaseYear = first.releaseYear ?? updated.releaseYear
        updated.posterURL = try await cacheImageIfNeeded(path: first.posterPath, size: "w500") ?? updated.posterURL
        updated.backdropURL = try await cacheImageIfNeeded(path: first.backdropPath, size: "w780") ?? updated.backdropURL
        return updated
    }

    private func cacheImageIfNeeded(path: String?, size: String) async throws -> URL? {
        guard let path else { return nil }
        guard let url = URL(string: "https://image.tmdb.org/t/p/\(size)\(path)") else { return nil }
        let data = try await client.get(url: url, headers: [:])
        return try imageCache.store(data: data, sourceURL: url)
    }

    // MARK: - TVDb

    private func fetchFromTVDb(token: String, item: MediaItem) async throws -> MediaItem? {
        let query = item.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.title
        guard let url = URL(string: "https://api4.thetvdb.com/v4/search?q=\(query)") else { return nil }
        let data = try await client.get(url: url, headers: ["Authorization": "Bearer \(token)"])
        let response = try JSONDecoder().decode(TVDbSearchResponse.self, from: data)
        guard let first = response.data.first else { return nil }

        var updated = item
        updated.originalTitle = first.slug ?? updated.originalTitle
        updated.overview = first.overview ?? updated.overview
        updated.releaseYear = first.releaseYear ?? updated.releaseYear

        if let poster = first.imageURL {
            let posterData = try await client.get(url: poster, headers: [:])
            updated.posterURL = try imageCache.store(data: posterData, sourceURL: poster)
        }

        if let backdrop = first.backgroundURL {
            let backdropData = try await client.get(url: backdrop, headers: [:])
            updated.backdropURL = try imageCache.store(data: backdropData, sourceURL: backdrop)
        }

        return updated
    }

    private func performWithRetry<T>(maxRetries: Int, baseDelay: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                attempt += 1
                if attempt > maxRetries { break }
                let delay = baseDelay * pow(2, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw MetadataError.retryExhausted(last: lastError ?? MetadataError.unavailableProvider)
    }
}

// MARK: - Cache

public enum MetadataCacheStatus: Equatable {
    case cached(URL)
    case missing
}

public final class MetadataImageCache {
    private let fileManager: FileManager
    private let cacheDirectory: URL

    public init(fileManager: FileManager = .default, cacheDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.cacheDirectory = base.appendingPathComponent("MetadataImages", isDirectory: true)
        }

        try? fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    public func store(data: Data, sourceURL: URL) throws -> URL {
        let filename = cacheFileName(for: sourceURL)
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    public func status(for imageURL: URL?) -> MetadataCacheStatus {
        guard let imageURL else { return .missing }

        if imageURL.isFileURL {
            return fileManager.fileExists(atPath: imageURL.path) ? .cached(imageURL) : .missing
        }

        let cachedURL = cacheDirectory.appendingPathComponent(cacheFileName(for: imageURL))
        return fileManager.fileExists(atPath: cachedURL.path) ? .cached(cachedURL) : .missing
    }

    private func cacheFileName(for url: URL) -> String {
        let input = url.absoluteString
        if let data = input.data(using: .utf8) {
            let hash = data.reduce(into: 0) { partial, byte in
                partial = (partial &* 31) &+ Int(byte)
            }
            let ext = url.pathExtension
            if ext.isEmpty {
                return "mdimg_\(hash)"
            }
            return "mdimg_\(hash).\(ext)"
        }
        return url.lastPathComponent
    }
}

// MARK: - DTOs

private struct TMDbSearchResponse: Decodable {
    let results: [TMDbMedia]
}

private struct TMDbMedia: Decodable {
    let title: String?
    let name: String?
    let originalTitle: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case title
        case name
        case originalTitle = "original_title"
        case overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }

    var displayTitle: String? { title ?? name }
    var releaseYear: Int? {
        let dateString = releaseDate ?? firstAirDate
        guard let yearString = dateString?.split(separator: "-").first else { return nil }
        return Int(yearString)
    }
}

private struct TVDbSearchResponse: Decodable {
    let data: [TVDbSearchEntry]
}

private struct TVDbSearchEntry: Decodable {
    let name: String?
    let slug: String?
    let overview: String?
    let firstAired: String?
    let imageURL: URL?
    let backgroundURL: URL?

    enum CodingKeys: String, CodingKey {
        case name
        case slug
        case overview
        case firstAired
        case imageURL = "image"
        case backgroundURL = "thumbnail" // TVDb v4 returns a thumbnail/backdrop-like image
    }

    var releaseYear: Int? {
        guard let firstAired else { return nil }
        return Int(firstAired.prefix(4))
    }
}
