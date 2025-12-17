import Foundation
import Common

public enum LibrarySource: Sendable {
    case local(URL)
    case smb(URL)
    case webdav(URL)
    case ftp(URL)
    case upnp(URL)
}

public struct ScanResult: Sendable {
    public let items: [MediaItem]
}

public protocol LibraryScannerProtocol {
    func scan(sources: [LibrarySource]) async -> ScanResult
}

public final class LibraryScanner: LibraryScannerProtocol {
    public init() {}

    public func scan(sources: [LibrarySource]) async -> ScanResult {
        var results: [MediaItem] = []
        for source in sources {
            switch source {
            case .local(let url):
                results.append(contentsOf: scanLocal(url: url))
            case .smb(let url), .webdav(let url), .ftp(let url), .upnp(let url):
                // In a real app, hook protocol clients; here return stub entries.
                results.append(MediaItem(title: url.lastPathComponent, type: .movie, url: url))
            }
        }
        return ScanResult(items: results)
    }

    private func scanLocal(url: URL) -> [MediaItem] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return [] }
        return items.map { path in
            MediaItem(title: path.deletingPathExtension().lastPathComponent, type: .movie, url: path)
        }
    }
}
