//
//  Error.swift
//  CueAnthropic
//

extension Anthropic {
    // MARK: - Errors
    public struct APIError: Decodable, Sendable {
        public let error: ErrorDetails

        public init(error: ErrorDetails) {
            self.error = error
        }

        public struct ErrorDetails: Decodable, Sendable {
            public let message: String
            public let type: String
        }
    }

    public enum Error: Swift.Error {
        case invalidResponse
        case networkError(Swift.Error)
        case decodingError(DecodingError)
        case apiError(APIError)
        case unexpectedAPIResponse(String)
        case toolUseError(String)
    }
}
