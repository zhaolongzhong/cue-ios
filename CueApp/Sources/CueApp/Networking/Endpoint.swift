import Foundation

protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var parameters: [String: Any]? { get }
    var body: Data? { get }
    var requiresAuth: Bool { get }
}

extension Endpoint {
    var baseURL: String {
        return EnvironmentConfig.getBaseAPIURL
    }

    var headers: [String: String]? {
        var platform = "ios"
        #if os(macOS)
            platform = "macos"
        #endif

        return [
            "Content-Type": "application/json",
            "platform": platform
        ]
    }

    var parameters: [String: Any]? {
        nil
    }

    var body: Data? {
        nil
    }

    var requiresAuth: Bool {
        true
    }

    func urlRequest(with token: String?, includeAdditionalHeaders: Bool = false) throws -> URLRequest {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw NetworkError.invalidURL
        }

        urlComponents.path = path

        if let parameters = parameters {
            urlComponents.queryItems = parameters.map {
                URLQueryItem(name: $0.key, value: "\($0.value)")
            }
        }

        let urlString = baseURL + path

        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body

        var finalHeaders = headers ?? [:]
        if requiresAuth, let token = token {
            finalHeaders["Authorization"] = "Bearer \(token)"
        }

        if includeAdditionalHeaders {
            finalHeaders["platform"] = "macos"
        }

        finalHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }
}
