import Foundation
import Common
import Networking

public protocol MetadataServiceProtocol {
    func fetchMetadata(for item: MediaItem) async throws -> MediaItem
}

public final class MetadataService: MetadataServiceProtocol {
    private let client: NetworkClientProtocol

    public init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    public func fetchMetadata(for item: MediaItem) async throws -> MediaItem {
        // Simulate fetching metadata from a TMDb-like API
        let path = "/metadata?title=\(item.title)"
        _ = try await client.get(path: path)

        var updated = item
        updated.overview = item.overview ?? "这是一段示例剧情简介。"
        updated.posterURL = updated.posterURL ?? URL(string: "https://example.com/poster.jpg")
        updated.backdropURL = updated.backdropURL ?? URL(string: "https://example.com/backdrop.jpg")
        return updated
    }
}
