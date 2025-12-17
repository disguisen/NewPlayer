import Foundation
import Common

public protocol LibraryPersistence {
    func loadItems() -> [MediaItem]
    func save(items: [MediaItem])
}

public final class InMemoryLibraryPersistence: LibraryPersistence {
    private var storage: [MediaItem]

    public init(seed: [MediaItem] = []) {
        self.storage = seed
    }

    public func loadItems() -> [MediaItem] {
        storage
    }

    public func save(items: [MediaItem]) {
        storage = items
    }
}

public final class SQLiteLibraryPersistence: LibraryPersistence {
    private let url: URL
    private let fallback: InMemoryLibraryPersistence

    public init(url: URL? = nil) {
        self.url = url ?? Self.defaultURL()
        self.fallback = InMemoryLibraryPersistence()
    }

    public func loadItems() -> [MediaItem] {
        fallback.loadItems()
    }

    public func save(items: [MediaItem]) {
        fallback.save(items: items)
    }

    static func defaultURL() -> URL {
        #if os(macOS)
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        #else
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        #endif
        let directory = paths[0].appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("media.sqlite")
    }
}
