import Foundation

public enum MCPServerError: LocalizedError, Sendable {
    case configNotFound(String)
    case invalidConfig(String)
    case serverInitializationFailed(String, Error?)
    case serverNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .configNotFound(let path):
            return "Configuration file not found at path: \(path)"
        case .invalidConfig(let details):
            return "Invalid configuration: \(details)"
        case .serverInitializationFailed(let server, let error):
            return "Failed to initialize server \(server): \(error?.localizedDescription ?? "unknown error")"
        case .serverNotFound(let server):
            return "Server not found: \(server)"
        }
    }
}
