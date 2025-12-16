import Foundation
import Common
import Networking

public protocol LibraryScannerProtocol {
    func scan(sources: [MediaScanSource]) async throws -> [MediaItem]
}

public final class LibraryScanner: LibraryScannerProtocol {
    private let networkClient: NetworkClientProtocol

    public init(networkClient: NetworkClientProtocol = NetworkClient()) {
        self.networkClient = networkClient
    }

    public func scan(sources: [MediaScanSource]) async throws -> [MediaItem] {
        var results: [MediaItem] = []
        for source in sources {
            switch source.scheme {
            case .local:
                results.append(contentsOf: try scanLocalDirectory(source.url))
            case .smb, .webdav, .ftp, .upnp:
                let remoteItems = try await scanRemoteSource(source)
                results.append(contentsOf: remoteItems)
            }
        }
        return results
    }

    private func scanLocalDirectory(_ url: URL) throws -> [MediaItem] {
        let fileManager = FileManager.default
        var items: [MediaItem] = []
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return items
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            let item = MediaItem(title: fileURL.deletingPathExtension().lastPathComponent, type: inferType(from: fileURL), localURL: fileURL)
            items.append(item)
        }
        return items
    }

    private func scanRemoteSource(_ source: MediaScanSource) async throws -> [MediaItem] {
        _ = try await networkClient.get(path: source.url.absoluteString)
        // Simulate receiving a directory listing for remote protocols.
        let simulatedFiles: [String] = [
            "Sample_Remote_Movie.mp4",
            "Sample_Remote_Episode_S01E01.mkv"
        ]

        return simulatedFiles.enumerated().map { _, name in
            let fileURL = source.url.appendingPathComponent(name)
            let type: MediaType = name.lowercased().contains("s01") ? .tvShow : .movie
            return MediaItem(
                title: "\(source.displayName) · \(name)",
                overview: "从 \(source.scheme.rawValue.uppercased()) 源发现的文件",
                type: type,
                releaseYear: Calendar.current.component(.year, from: Date()),
                runtime: type == .movie ? 5400 : 3600,
                posterURL: nil,
                backdropURL: nil,
                localURL: fileURL,
                subtitles: [],
                audioTracks: [],
                lastPlaybackPosition: 0,
                lastPlaybackDate: nil
            )
        }
    }

    private func inferType(from url: URL) -> MediaType {
        let ext = url.pathExtension.lowercased()
        if ["mp3", "flac", "aac"].contains(ext) {
            return .music
        }
        if url.lastPathComponent.lowercased().contains("s01e") {
            return .tvShow
        }
        return .movie
    }
}
