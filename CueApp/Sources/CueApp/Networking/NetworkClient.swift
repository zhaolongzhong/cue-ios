import Foundation
import os.log

actor NetworkClient {
    private let session: URLSession
    private let logger = Logger(subsystem: "NetworkClient", category: "Network")
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    static let shared = NetworkClient()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300

        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T {
        let token = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY")
        if endpoint.requiresAuth && (token == nil || token?.isEmpty == true) {
            throw NetworkError.unauthorized
        }
        let request = try endpoint.urlRequest(with: token)

        logger.debug("Making request to \(request.url?.absoluteString ?? "unknown URL")")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoded = try decoder.decode(T.self, from: data)
                return decoded
            } catch {
                logger.error("Decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        logger.error("Key '\(String(describing: key))' not found: \(String(describing: context.debugDescription))")
                    case .valueNotFound(let type, let context):
                        logger.error("Value of type '\(type)' not found: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        logger.error("Type '\(type)' mismatch: \(context.debugDescription)")
                    default:
                        logger.error("Other decoding error: \(decodingError)")
                    }
                }
                throw NetworkError.decodingError(error)
            }

        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            throw NetworkError.httpError(httpResponse.statusCode, data)
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.httpError(httpResponse.statusCode, data)
        }
    }

    func requestWithEmptyResponse(_ endpoint: Endpoint) async throws {
        let token = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY")
        let request = try endpoint.urlRequest(with: token)

        logger.debug("Making request to \(request.url?.absoluteString ?? "unknown URL")")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            throw NetworkError.httpError(httpResponse.statusCode, nil)
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.httpError(httpResponse.statusCode, nil)
        }
    }

    func upload(_ endpoint: Endpoint, data: Data, mimeType: String) async throws -> Data {
        let token = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY")
        var request = try endpoint.urlRequest(with: token)

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add the file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"file\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // Add the closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return responseData
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            throw NetworkError.httpError(httpResponse.statusCode, responseData)
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.httpError(httpResponse.statusCode, responseData)
        }
    }
}
