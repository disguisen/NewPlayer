import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Common

public struct NetworkRequest: Sendable {
    public let url: URL
    public let headers: [String: String]

    public init(url: URL, headers: [String: String] = [:]) {
        self.url = url
        self.headers = headers
    }
}

public protocol NetworkClientProtocol {
    func get(_ request: NetworkRequest) async throws -> Data
}

public final class NetworkClient: NetworkClientProtocol {
    public init() {}

    public func get(_ request: NetworkRequest) async throws -> Data {
        var urlRequest = URLRequest(url: request.url)
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        #if canImport(FoundationNetworking)
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        return data
        #else
        if #available(iOS 15, macOS 12, *) {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            return data
        } else {
            throw URLError(.badServerResponse)
        }
        #endif
    }
}
