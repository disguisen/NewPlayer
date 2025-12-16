import Foundation

public enum MediaType: String, Codable, CaseIterable {
    case movie
    case tvShow
    case music
}

public enum MediaSourceScheme: String, Codable, CaseIterable {
    case local
    case smb
    case webdav
    case ftp
    case upnp
}

public struct MediaScanSource: Codable, Hashable {
    public var scheme: MediaSourceScheme
    public var url: URL
    public var username: String?
    public var password: String?
    public var displayName: String

    public init(
        scheme: MediaSourceScheme,
        url: URL,
        username: String? = nil,
        password: String? = nil,
        displayName: String
    ) {
        self.scheme = scheme
        self.url = url
        self.username = username
        self.password = password
        self.displayName = displayName
    }
}

public struct MediaItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public var title: String
    public var originalTitle: String?
    public var overview: String?
    public var type: MediaType
    public var releaseYear: Int?
    public var runtime: TimeInterval?
    public var posterURL: URL?
    public var backdropURL: URL?
    public var localURL: URL?
    public var subtitles: [Subtitle]
    public var audioTracks: [AudioTrack]
    public var lastPlaybackPosition: TimeInterval
    public var lastPlaybackDate: Date?

    public init(
        id: UUID = .init(),
        title: String,
        originalTitle: String? = nil,
        overview: String? = nil,
        type: MediaType,
        releaseYear: Int? = nil,
        runtime: TimeInterval? = nil,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        localURL: URL? = nil,
        subtitles: [Subtitle] = [],
        audioTracks: [AudioTrack] = [],
        lastPlaybackPosition: TimeInterval = 0,
        lastPlaybackDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.overview = overview
        self.type = type
        self.releaseYear = releaseYear
        self.runtime = runtime
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.localURL = localURL
        self.subtitles = subtitles
        self.audioTracks = audioTracks
        self.lastPlaybackPosition = lastPlaybackPosition
        self.lastPlaybackDate = lastPlaybackDate
    }
}

public struct Subtitle: Identifiable, Codable, Hashable {
    public let id: UUID
    public var languageCode: String
    public var name: String
    public var url: URL
    public var isDefault: Bool

    public init(id: UUID = .init(), languageCode: String, name: String, url: URL, isDefault: Bool = false) {
        self.id = id
        self.languageCode = languageCode
        self.name = name
        self.url = url
        self.isDefault = isDefault
    }
}

public struct AudioTrack: Identifiable, Codable, Hashable {
    public let id: UUID
    public var languageCode: String
    public var name: String
    public var isDefault: Bool

    public init(id: UUID = .init(), languageCode: String, name: String, isDefault: Bool = false) {
        self.id = id
        self.languageCode = languageCode
        self.name = name
        self.isDefault = isDefault
    }
}

public enum PlayerError: Error, LocalizedError, Equatable {
    case fileNotFound
    case unsupportedFormat
    case decodeFailed
    case networkUnavailable
    case subtitleMissing

    public var errorDescription: String? {
        switch self {
        case .fileNotFound: return "未找到媒体文件"
        case .unsupportedFormat: return "不支持的媒体格式"
        case .decodeFailed: return "解码失败"
        case .networkUnavailable: return "网络不可用"
        case .subtitleMissing: return "字幕缺失"
        }
    }
}
