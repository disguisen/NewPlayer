import Foundation
import Common

public protocol LibraryServiceProtocol {
    var items: [MediaItem] { get }
    func refresh(sources: [LibrarySource]) async
}

public final class LibraryService: LibraryServiceProtocol {
    public private(set) var items: [MediaItem] = []
    private let scanner: LibraryScannerProtocol
    private let metadata: MetadataServiceProtocol
    private let persistence: LibraryPersistence

    public init(scanner: LibraryScannerProtocol = LibraryScanner(), metadata: MetadataServiceProtocol = MetadataService(), persistence: LibraryPersistence = SQLiteLibraryPersistence()) {
        self.scanner = scanner
        self.metadata = metadata
        self.persistence = persistence
        self.items = persistence.loadItems()
    }

    public func refresh(sources: [LibrarySource]) async {
        let scan = await scanner.scan(sources: sources)
        let enriched = await metadata.enrich(items: scan.items)
        persistence.save(items: enriched)
        self.items = enriched
    }
}
