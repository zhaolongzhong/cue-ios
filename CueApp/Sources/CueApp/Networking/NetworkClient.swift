import Foundation
import os.log

struct APIError: Codable {
    let message: String?
    let detail: String?
    let code: String?
    let details: [String: String]?
}

actor NetworkClient {
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

    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T {
        do {
            return try await performRequest(endpoint)
        } catch NetworkError.forbidden(let message) where message == "Token expired" {
            // Try to refresh the token and retry the request
            let newTokens = try await refreshTokens()
            print("inx refreshed tokens: \(newTokens)")
            await TokenManager.shared.saveTokens(
                accessToken: newTokens.accessToken,
                refreshToken: newTokens.refreshToken
            )
            return try await performRequest(endpoint)
        } catch {
            print("inx error: \(error)")
            throw error
        }
    }

    private func performRequest<T: Codable>(_ endpoint: Endpoint) async throws -> T {
        let token = await TokenManager.shared.accessToken

        if endpoint.requiresAuth && (token == nil || token?.isEmpty == true) {
            throw NetworkError.unauthorized
        }
        let request = try endpoint.urlRequest(with: token)

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
        case 403:
            let errorResponse = try? decoder.decode(APIError.self, from: data)
            logger.error("Forbidden: \(String(describing: errorResponse?.detail))")
            throw NetworkError.forbidden(message: errorResponse?.detail ?? "Token expired")
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
