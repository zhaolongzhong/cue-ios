import Foundation

public struct ServerError: Codable, Sendable {
    public let eventId: String
    public let type: String
    public let error: ErrorDetail
}

public struct ErrorDetail: Codable, Sendable {
    public let type: String
    public let code: String?
    public let message: String
    public let param: String?
    public let eventId: String?
}

extension OpenAI {
    public struct APIError: Decodable, Sendable {
        public let error: ErrorDetails

        public struct ErrorDetails: Decodable, Sendable {
            public let message: String
            public let type: String
            public let param: String?
            public let code: String?
        }
    }

    public enum Error: Swift.Error {
        case invalidResponse
        case networkError(Swift.Error)
        case decodingError(DecodingError)
        case apiError(APIError)
        case unexpectedAPIResponse(String)
    }
}

extension OpenAI.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from the server."
        case .networkError(let underlyingError):
            return "Network error: \(underlyingError.localizedDescription)"
        case .decodingError(let decodingError):
            return "Decoding error: \(decodingError.localizedDescription)"
        case .apiError(let apiError):
            return "API error: \(apiError.error.message) (Code: \(apiError.error.code ?? ""), Type: \(apiError.error.type))"
        case .unexpectedAPIResponse(let message):
            return "Unexpected API response: \(message)"
        }
    }
}
