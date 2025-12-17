import Foundation

public enum MediaType: String, Codable, Sendable {
    case movie
    case episode
    case music
}

public struct MediaItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var type: MediaType
    public var url: URL?
    public var duration: TimeInterval?
    public var artworkURL: URL?
    public var backdropURL: URL?
    public var overview: String?
    public var season: Int?
    public var episode: Int?

    public init(
        id: UUID = UUID(),
        title: String,
        type: MediaType,
        url: URL? = nil,
        duration: TimeInterval? = nil,
        artworkURL: URL? = nil,
        backdropURL: URL? = nil,
        overview: String? = nil,
        season: Int? = nil,
        episode: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.url = url
        self.duration = duration
        self.artworkURL = artworkURL
        self.backdropURL = backdropURL
        self.overview = overview
        self.season = season
        self.episode = episode
    }
}

public struct AudioTrack: Codable, Sendable, Identifiable {
    public var id: String { languageCode }
    public let languageCode: String
    public let title: String?
}

public struct SubtitleTrack: Codable, Sendable, Identifiable {
    public var id: String { languageCode }
    public let languageCode: String
    public let title: String?
    public let url: URL?
}

public struct PlaybackState: Sendable {
    public var isPlaying: Bool
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var buffered: TimeInterval
    public var rate: Float

    public init(
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        buffered: TimeInterval,
        rate: Float
    ) {
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.buffered = buffered
        self.rate = rate
    }
}

public enum PlayerError: Error, Sendable {
    case failedToLoad
    case decodeFailed
    case unknown
}
