import Foundation

public protocol NetworkClientProtocol {
    func get(path: String) async throws -> Data
    func get(url: URL, headers: [String: String]) async throws -> Data
}

public final class NetworkClient: NetworkClientProtocol {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(path: String) async throws -> Data {
        if let url = URL(string: path), url.scheme != nil {
            return try await get(url: url, headers: [:])
        }

        // Simulated call for relative paths in preview/demo environments.
        try await Task.sleep(nanoseconds: 50_000_000)
        return Data("mock-response".utf8)
    }

    public func get(url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) == false {
            throw URLError(.badServerResponse)
        }

        return data
    }
}
