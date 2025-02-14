import Foundation

enum GmailServiceError: LocalizedError {
    case authenticationError
    case permissionDenied
    case networkError(Error)
    case invalidResponse(String)
    case tokenStorageError
    case tokenRefreshError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .authenticationError:
            return "Gmail authentication required"
        case .permissionDenied:
            return "Gmail access denied"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let error):
            return "Invalid response from Gmail: \(error)"
        case .tokenStorageError:
            return "Error storing Gmail access token"
        case .tokenRefreshError:
            return "Error refreshing Gmail access token"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

struct GoogleTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}
