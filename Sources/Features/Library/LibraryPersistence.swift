import Foundation
#if canImport(SQLite3)
import SQLite3
#endif
import Common

public protocol LibraryPersisting {
    func loadAll() throws -> [MediaItem]
    func upsert(items: [MediaItem]) throws
    func updatePlaybackPosition(itemID: UUID, position: TimeInterval, date: Date) throws
}

#if canImport(SQLite3)
public final class SQLiteLibraryPersistence: LibraryPersisting {
    private let db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "library.persistence.queue")

    public init(path: URL = SQLiteLibraryPersistence.defaultURL()) throws {
        var dbPointer: OpaquePointer?
        let directory = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if sqlite3_open(path.path, &dbPointer) != SQLITE_OK {
            throw PersistenceError.connectionFailed
        }
        db = dbPointer
        try createTableIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    public func loadAll() throws -> [MediaItem] {
        try perform {
            let query = "SELECT payload FROM media_items"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw PersistenceError.queryFailed
            }
            defer { sqlite3_finalize(statement) }

            var items: [MediaItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let blobPointer = sqlite3_column_blob(statement, 0) else { continue }
                let blobSize = sqlite3_column_bytes(statement, 0)
                let data = Data(bytes: blobPointer, count: Int(blobSize))
                if let item = try? decoder.decode(MediaItem.self, from: data) {
                    items.append(item)
                }
            }
            return items
        }
    }

    public func upsert(items: [MediaItem]) throws {
        try perform {
            let query = "INSERT OR REPLACE INTO media_items(id, payload, updated_at) VALUES(?,?,?)"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw PersistenceError.queryFailed
            }
            defer { sqlite3_finalize(statement) }

            for item in items {
                let data = try encoder.encode(item)
                sqlite3_bind_text(statement, 1, item.id.uuidString, -1, SQLITE_TRANSIENT)
                data.withUnsafeBytes { bytes in
                    _ = sqlite3_bind_blob(statement, 2, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
                }
                sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw PersistenceError.queryFailed
                }
                sqlite3_reset(statement)
            }
        }
    }

    public func updatePlaybackPosition(itemID: UUID, position: TimeInterval, date: Date) throws {
        try perform {
            let query = "UPDATE media_items SET payload = ?, updated_at = ? WHERE id = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw PersistenceError.queryFailed
            }
            defer { sqlite3_finalize(statement) }

            let existingItems = try loadAll()
            guard let updated = existingItems.first(where: { $0.id == itemID }) else { return }
            var edited = updated
            edited.lastPlaybackPosition = position
            edited.lastPlaybackDate = date
            let data = try encoder.encode(edited)

            data.withUnsafeBytes { bytes in
                _ = sqlite3_bind_blob(statement, 1, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            }
            sqlite3_bind_double(statement, 2, date.timeIntervalSince1970)
            sqlite3_bind_text(statement, 3, itemID.uuidString, -1, SQLITE_TRANSIENT)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw PersistenceError.queryFailed
            }
        }
    }

    private func createTableIfNeeded() throws {
        let createSQL = """
        CREATE TABLE IF NOT EXISTS media_items (
            id TEXT PRIMARY KEY,
            payload BLOB NOT NULL,
            updated_at REAL
        );
        """

        guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
            throw PersistenceError.queryFailed
        }
    }

    private func perform<T>(_ block: @escaping () throws -> T) throws -> T {
        var result: Result<T, Error>!
        queue.sync {
            result = Result { try block() }
        }
        return try result.get()
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        return base.appendingPathComponent("NewPlayer/library.sqlite")
    }
}
#endif

public enum PersistenceError: Error {
    case connectionFailed
    case queryFailed
}

public final class InMemoryLibraryPersistence: LibraryPersisting {
    private var cache: [UUID: MediaItem] = [:]

    public init() {}

    public func loadAll() throws -> [MediaItem] {
        Array(cache.values)
    }

    public func upsert(items: [MediaItem]) throws {
        for item in items { cache[item.id] = item }
    }

    public func updatePlaybackPosition(itemID: UUID, position: TimeInterval, date: Date) throws {
        guard var item = cache[itemID] else { return }
        item.lastPlaybackDate = date
        item.lastPlaybackPosition = position
        cache[itemID] = item
    }
}
