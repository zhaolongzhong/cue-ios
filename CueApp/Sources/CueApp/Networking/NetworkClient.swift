import Foundation
import os.log

struct APIError: Codable {
    let message: String?
    let detail: String?
    let code: String?
    let details: [String: String]?
}

protocol NetworkClientProtocol: Actor {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

actor NetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let logger = Logger(subsystem: "NetworkClient", category: "Network")
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var isRefreshing = false
    private var refreshTask: Task<TokenResponse, Error>?

    static let shared = NetworkClient()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300

        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        do {
            return try await performRequest(endpoint)
        } catch NetworkError.forbidden(let message) where message == "Token expired" {
            let newTokens = try await refreshTokens()
            await TokenManager.shared.saveTokens(
                accessToken: newTokens.accessToken,
                refreshToken: newTokens.refreshToken
            )
            return try await performRequest(endpoint)
        } catch {
            throw error
        }
    }

    private func performRequest<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let token = await TokenManager.shared.accessToken
        try validateAuthToken(token, requiresAuth: endpoint.requiresAuth)

        let request = try endpoint.urlRequest(with: token)
        logRequest(request)

        let (data, response) = try await session.data(for: request)
        let httpResponse = try validateHTTPResponse(response)

        try handleHTTPStatusCode(httpResponse.statusCode, data: data)
        return try decodeResponse(data)
    }

    private func validateAuthToken(_ token: String?, requiresAuth: Bool) throws {
        if requiresAuth && (token == nil || token?.isEmpty == true) {
            logger.debug("Unauthorized: missing or empty token")
            throw NetworkError.unauthorized
        }
    }

    private func logRequest(_ request: URLRequest) {
        logger.debug("Performing request: \(request.httpMethod ?? "N/A") \(request.url?.absoluteString ?? "unknown URL")")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("Request body: \(bodyString)")
        }
    }

    private func validateHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response: \(response)")
            throw NetworkError.invalidResponse
        }
        return httpResponse
    }

    private func handleHTTPStatusCode(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299:
            #if DEBUG
            logRawResponse(data)
            #endif
        case 401:
            logger.error("Unauthorized error: \(statusCode)")
            throw NetworkError.unauthorized
        case 403:
            throw try handleForbiddenError(data)
        case 400...499:
            logger.error("HTTP client error: \(statusCode)")
            throw NetworkError.httpError(statusCode, data)
        case 500...599:
            logger.error("Server error: \(statusCode)")
            throw NetworkError.serverError
        default:
            logger.error("Unhandled HTTP status code: \(statusCode)")
            throw NetworkError.httpError(statusCode, data)
        }
    }

    private func handleForbiddenError(_ data: Data) throws -> NetworkError {
        let errorResponse = try? decoder.decode(APIError.self, from: data)
        let message = errorResponse?.detail ?? "Token expired"
        logger.error("Forbidden error: 403 - \(message)")
        return NetworkError.forbidden(message: message)
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.debug("Default decoding failed: \(error)")
            return try decodeWithSnakeCase(data)
        }
    }

    private func decodeWithSnakeCase<T: Decodable>(_ data: Data) throws -> T {
        do {
            let altDecoder = JSONDecoder()
            altDecoder.keyDecodingStrategy = .convertFromSnakeCase
            logger.debug("Attempting decoding with convertFromSnakeCase")
            return try altDecoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding error with convertFromSnakeCase: \(error)")
            logRawResponse(data)
            throw NetworkError.decodingError(error)
        }
    }

    private func logRawResponse(_ data: Data) {
        if let raw = String(data: data, encoding: .utf8) {
//            logger.debug("Raw response: \(raw)")
        }
    }

    private func refreshTokens() async throws -> TokenResponse {
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        guard let refreshToken = await TokenManager.shared.refreshToken else {
            throw AuthError.refreshTokenMissing
        }

        let task = Task<TokenResponse, Error> {
            let endpoint = AuthEndpoint.refreshToken(token: refreshToken)
            do {
                let response: TokenResponse = try await performRequest(endpoint)
                return response
            } catch {
                if case NetworkError.forbidden = error {
                    await TokenManager.shared.clearTokens()
                    throw AuthError.refreshTokenExpired
                }
                throw error
            }
        }

        refreshTask = task
        defer { refreshTask = nil }

        return try await task.value
    }
}

protocol DebugPrintable: Encodable {
    func debugJSON() -> String
}

extension DebugPrintable {
    func debugJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "Failed to encode"
        } catch {
            return "Failed to encode: \(error)"
        }
    }
}

extension NetworkClient {
    func requestStream<T: Decodable>(
        _ endpoint: Endpoint,
        onChunk: @escaping @Sendable (T) async -> Void
    ) async throws {
        let token = await TokenManager.shared.accessToken
        try validateAuthToken(token, requiresAuth: endpoint.requiresAuth)

        let request = try endpoint.urlRequest(with: token)
        logRequest(request)

        let (bytes, response) = try await session.bytes(for: request)
        let httpResponse = try validateHTTPResponse(response)
        try handleHTTPStatusCode(httpResponse.statusCode, data: Data())

        var buffer = ""

        for try await byte in bytes {
            guard let char = String(bytes: [byte], encoding: .utf8) else {
                continue
            }

            buffer += char

            if char == "\n" && !buffer.isEmpty {
                do {
                    if let data = buffer.data(using: .utf8) {
                        let chunk = try decoder.decode(T.self, from: data)
                        await onChunk(chunk)
                    }
                } catch {
                    logger.error("Failed to decode chunk: \(error)")
                    throw error
                }

                buffer = ""
            }
        }
    }
}
