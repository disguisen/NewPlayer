import Foundation
import Common

public protocol LibraryServiceProtocol {
    func loadLibrary() async throws -> [MediaItem]
    func scanAndImport(sources: [MediaScanSource]) async throws -> [MediaItem]
    func savePlaybackProgress(for item: MediaItem, position: TimeInterval) async
    func updateMetadata(for item: MediaItem) async throws -> MediaItem
}

public final class LibraryService: LibraryServiceProtocol {
    private let metadataService: MetadataServiceProtocol
    private let storage: LibraryStorage
    private let scanner: LibraryScannerProtocol

    public init(
        metadataService: MetadataServiceProtocol = MetadataService(),
        storage: LibraryStorage = LibraryStorage(),
        scanner: LibraryScannerProtocol = LibraryScanner()
    ) {
        self.metadataService = metadataService
        self.storage = storage
        self.scanner = scanner
    }

    public func loadLibrary() async throws -> [MediaItem] {
        try await storage.loadItems()
    }

    public func scanAndImport(sources: [MediaScanSource]) async throws -> [MediaItem] {
        let scanned = try await scanner.scan(sources: sources)
        try await storage.save(items: scanned)
        return scanned
    }

    public func savePlaybackProgress(for item: MediaItem, position: TimeInterval) async {
        await storage.updatePlaybackPosition(itemID: item.id, position: position)
    }

    public func updateMetadata(for item: MediaItem) async throws -> MediaItem {
        let enriched = try await metadataService.fetchMetadata(for: item)
        try await storage.save(items: [enriched])
        return enriched
    }
}

public actor LibraryStorage {
    private var cache: [UUID: MediaItem] = [:]
    private let persistence: LibraryPersisting

    public init(persistence: LibraryPersisting? = nil) {
        if let persistence {
            self.persistence = persistence
        } else if let sqlite = try? SQLiteLibraryPersistence() {
            self.persistence = sqlite
        } else {
            self.persistence = InMemoryLibraryPersistence()
        }
    }

    public func loadItems() async throws -> [MediaItem] {
        if cache.isEmpty {
            let persisted = try persistence.loadAll()
            if persisted.isEmpty {
                let seeded = seedInitialItems()
                try persistence.upsert(items: seeded)
                for item in seeded { cache[item.id] = item }
            } else {
                for item in persisted { cache[item.id] = item }
            }
        }
        return Array(cache.values)
    }

    public func save(items: [MediaItem]) async throws {
        for item in items {
            cache[item.id] = item
        }
        try persistence.upsert(items: items)
    }

    public func updatePlaybackPosition(itemID: UUID, position: TimeInterval) async {
        guard var item = cache[itemID] else { return }
        item.lastPlaybackPosition = position
        item.lastPlaybackDate = Date()
        cache[itemID] = item
        try? persistence.updatePlaybackPosition(itemID: itemID, position: position, date: item.lastPlaybackDate ?? Date())
    }

    private func seedInitialItems() -> [MediaItem] {
        let sampleSubtitles = [
            Subtitle(languageCode: "zh", name: "简体中文字幕", url: URL(fileURLWithPath: "/tmp/movie.zh.srt"), isDefault: true),
            Subtitle(languageCode: "en", name: "English CC", url: URL(fileURLWithPath: "/tmp/movie.en.srt"))
        ]
        let sampleAudio = [
            AudioTrack(languageCode: "en", name: "英语原声", isDefault: true),
            AudioTrack(languageCode: "zh", name: "中文配音")
        ]

        let samples: [MediaItem] = [
            MediaItem(
                title: "示例电影：追光",
                originalTitle: "Chasing the Light",
                overview: "在一个永不入夜的城市，一名工程师试图重启太阳能网络。",
                type: .movie,
                releaseYear: 2024,
                runtime: 7200,
                posterURL: URL(string: "https://example.com/poster-chase.jpg"),
                backdropURL: URL(string: "https://example.com/backdrop-chase.jpg"),
                localURL: URL(fileURLWithPath: "/tmp/chasing-the-light.mp4"),
                subtitles: sampleSubtitles,
                audioTracks: sampleAudio,
                lastPlaybackPosition: 120
            ),
            MediaItem(
                title: "科幻剧集：星河站 第1集",
                originalTitle: "Starhub S01E01",
                overview: "宇航站迎来新成员，一场神秘信号正在靠近。",
                type: .tvShow,
                releaseYear: 2023,
                runtime: 3600,
                posterURL: URL(string: "https://example.com/poster-starhub.jpg"),
                backdropURL: URL(string: "https://example.com/backdrop-starhub.jpg"),
                localURL: URL(fileURLWithPath: "/tmp/starhub-101.mkv"),
                subtitles: sampleSubtitles,
                audioTracks: sampleAudio,
                lastPlaybackPosition: 0
            )
        ]

        for item in samples {
            cache[item.id] = item
        }
        return samples
    }
}
