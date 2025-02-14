import Foundation

public enum LiveAPIClientError: Error {
    case invalidURL
    case encodingError
    case audioError(message: String)
    case unknown(message: String? = nil)
}
