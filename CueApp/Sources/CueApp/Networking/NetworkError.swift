import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, Data?)
    case decodingError(Error)
    case forbidden(message: String)
    case unauthorized
    case serverError
    case networkError(Error)
    case invalidRequest
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, _):
            return "HTTP Error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        case .forbidden(let message):
            return "Forbidden: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError:
            return "Server error"
        case .networkError(let error):
            return error.localizedDescription
        case .invalidRequest:
            return "Invalid request"
        case .noData:
            return "No data received"
        }
    }

    var isAuthError: Bool {
        switch self {
        case .httpError(let statusCode, _):
            return statusCode == 401
        case .unauthorized:
            return true
        default:
            return false
        }
    }
}
