import Foundation
import Common

public protocol LibraryServiceProtocol {
    func loadLibrary() async throws -> [MediaItem]
    func savePlaybackProgress(for item: MediaItem, position: TimeInterval) async
    func updateMetadata(for item: MediaItem) async throws -> MediaItem
}

public final class LibraryService: LibraryServiceProtocol {
    private let metadataService: MetadataServiceProtocol
    private let storage: LibraryStorage

    public init(metadataService: MetadataServiceProtocol = MetadataService(), storage: LibraryStorage = LibraryStorage()) {
        self.metadataService = metadataService
        self.storage = storage
    }

    public func loadLibrary() async throws -> [MediaItem] {
        return try await storage.loadItems()
    }

    public func savePlaybackProgress(for item: MediaItem, position: TimeInterval) async {
        await storage.updatePlaybackPosition(itemID: item.id, position: position)
    }

    public func updateMetadata(for item: MediaItem) async throws -> MediaItem {
        let enriched = try await metadataService.fetchMetadata(for: item)
        await storage.save(items: [enriched])
        return enriched
    }
}

public final class LibraryStorage {
    private var cache: [UUID: MediaItem] = [:]
    private let queue = DispatchQueue(label: "library.storage.queue")

    public init() {}

    public func loadItems() async throws -> [MediaItem] {
        return await queue.sync { Array(cache.values) }
    }

    public func save(items: [MediaItem]) async {
        await queue.sync {
            for item in items {
                cache[item.id] = item
            }
        }
    }

    public func updatePlaybackPosition(itemID: UUID, position: TimeInterval) async {
        await queue.sync {
            guard var item = cache[itemID] else { return }
            item.lastPlaybackPosition = position
            item.lastPlaybackDate = Date()
            cache[itemID] = item
        }
    }
}
