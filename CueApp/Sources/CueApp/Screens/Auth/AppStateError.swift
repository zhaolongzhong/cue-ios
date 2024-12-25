import Foundation

public enum AppStateError: LocalizedError {
    case sessionExpired
    case networkError
    case profileFetchFailed(Error)
    case unauthorized
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "Session expired. Please log in again."
        case .networkError:
            return "Network error occurred. Please try again."
        case .profileFetchFailed:
            return "Failed to fetch user profile."
        case .unauthorized:
            return "You are not authorized. Please log in."
        case .unknown:
            return "An unexpected error occurred."
        }
    }
    
    public var logDescription: String {
        switch self {
        case .sessionExpired:
            return "Session expired"
        case .networkError:
            return "Network error"
        case .profileFetchFailed(let error):
            return "Profile fetch failed: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}