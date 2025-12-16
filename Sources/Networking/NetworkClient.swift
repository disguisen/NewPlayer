import Foundation

public protocol NetworkClientProtocol {
    func get(path: String) async throws -> Data
}

public final class NetworkClient: NetworkClientProtocol {
    public init() {}

    public func get(path: String) async throws -> Data {
        // In a production app, this would call out to URLSession/Alamofire.
        // We simulate latency for now.
        try await Task.sleep(nanoseconds: 50_000_000)
        return Data("mock-response".utf8)
    }
}
