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
        configuration.timeoutIntervalForRequest = 30
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

        if endpoint.requiresAuth && (token == nil || token?.isEmpty == true) {
            logger.debug("Unauthorized: missing or empty token")
            throw NetworkError.unauthorized
        }

        let request = try endpoint.urlRequest(with: token)
        logger.debug("Performing request: \(request.httpMethod ?? "N/A") \(request.url?.absoluteString ?? "unknown URL")")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("Request body: \(bodyString)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response: \(response)")
            throw NetworkError.invalidResponse
        }

        logger.debug("HTTP status code: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            #if DEBUG
            if let raw = String(data: data, encoding: .utf8) {
                logger.debug("Raw response: \(raw)")
            }
            #endif
            do {
                logger.debug("Attempting default decoding")
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.debug("Default decoding failed: \(error)")
                do {
                    let altDecoder = JSONDecoder()
                    altDecoder.keyDecodingStrategy = .convertFromSnakeCase
                    logger.debug("Attempting decoding with convertFromSnakeCase")
                    return try altDecoder.decode(T.self, from: data)
                } catch {
                    logger.error("Decoding error with convertFromSnakeCase: \(error)")
                    if let raw = String(data: data, encoding: .utf8) {
                        logger.error("Raw response data: \(raw)")
                    }
                    throw NetworkError.decodingError(error)
                }
            }
        case 401:
            logger.error("Unauthorized error: \(httpResponse.statusCode)")
            throw NetworkError.unauthorized
        case 403:
            let errorResponse = try? decoder.decode(APIError.self, from: data)
            let message = errorResponse?.detail ?? "Token expired"
            logger.error("Forbidden error: \(httpResponse.statusCode) - \(message)")
            throw NetworkError.forbidden(message: message)
        case 400...499:
            logger.error("HTTP client error: \(httpResponse.statusCode)")
            throw NetworkError.httpError(httpResponse.statusCode, data)
        case 500...599:
            logger.error("Server error: \(httpResponse.statusCode)")
            throw NetworkError.serverError
        default:
            logger.error("Unhandled HTTP status code: \(httpResponse.statusCode)")
            throw NetworkError.httpError(httpResponse.statusCode, data)
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
